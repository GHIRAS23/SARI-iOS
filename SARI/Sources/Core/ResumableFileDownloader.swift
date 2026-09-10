import Foundation

/// Background-capable downloader for very large optional assets such as GGUF models.
/// The URLSession is owned by the app rather than by a SwiftUI screen, so navigating
/// away from the setup view does not cancel the transfer. iOS can continue a
/// background URLSession transfer while the app is suspended and can relaunch the
/// app to deliver completion events.
final class ResumableFileDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let shared = ResumableFileDownloader()
    static let backgroundSessionIdentifier = "sa.sari.app.fiqh-model.background.v1"

    struct ProgressSnapshot: Sendable {
        let writtenBytes: Int64
        let expectedBytes: Int64
        let bytesPerSecond: Double
    }

    enum DownloadError: LocalizedError {
        case busy
        case invalidResponse
        case httpStatus(Int)
        case unableToStoreFile

        var errorDescription: String? {
            switch self {
            case .busy:
                return "A large-file download is already running."
            case .invalidResponse:
                return "The download server returned an invalid response."
            case .httpStatus(let code):
                return "The download server returned HTTP \(code)."
            case .unableToStoreFile:
                return "The downloaded file could not be stored on the device."
            }
        }
    }

    private struct TransferMetadata: Codable {
        let sourceURL: String
        let destinationPath: String
        let resumeDataPath: String
    }

    private let lock = NSLock()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(
            withIdentifier: Self.backgroundSessionIdentifier
        )
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 24 * 60 * 60
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private var continuation: CheckedContinuation<URL, Error>?
    private var progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
    private var currentTaskIdentifier: Int?
    private var currentMetadata: TransferMetadata?
    private var lastSampleDate = Date()
    private var lastSampleBytes: Int64 = 0
    private var startedFromResumeData = false
    private var completedTaskIdentifiers = Set<Int>()
    private var backgroundCompletionHandler: (() -> Void)?

    private override init() {
        super.init()
    }

    /// Reconnect the delegate to an existing iOS background session as early as app launch.
    func prepareBackgroundSession() {
        _ = session
    }

    /// Called by UIApplicationDelegate when iOS wakes the app to finish background events.
    func setBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
        lock.lock()
        backgroundCompletionHandler = handler
        lock.unlock()
        _ = session
    }

    func hasActiveDownload(from url: URL) async -> Bool {
        let tasks = await allTasks()
        return tasks.contains { task in
            guard let downloadTask = task as? URLSessionDownloadTask,
                  let metadata = metadata(for: downloadTask) else { return false }
            return metadata.sourceURL == url.absoluteString
                && downloadTask.state != .completed
                && downloadTask.state != .canceling
        }
    }

    func download(
        from url: URL,
        to destination: URL,
        resumeDataAt resumeURL: URL,
        progress: @escaping @Sendable (ProgressSnapshot) -> Void
    ) async throws -> URL {
        let existing = await matchingTask(for: url)

        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            defer { lock.unlock() }

            guard self.continuation == nil else {
                continuation.resume(throwing: DownloadError.busy)
                return
            }

            let metadata = TransferMetadata(
                sourceURL: url.absoluteString,
                destinationPath: destination.path,
                resumeDataPath: resumeURL.path
            )

            self.continuation = continuation
            self.progressHandler = progress
            self.currentMetadata = metadata
            self.lastSampleDate = Date()
            self.lastSampleBytes = 0
            self.startedFromResumeData = false

            if let existing {
                self.currentTaskIdentifier = existing.taskIdentifier
                if existing.taskDescription == nil {
                    existing.taskDescription = self.encodeMetadata(metadata)
                }
                let written = max(existing.countOfBytesReceived, 0)
                let expected = max(existing.countOfBytesExpectedToReceive, 0)
                self.lastSampleBytes = written
                progress(.init(writtenBytes: written, expectedBytes: expected, bytesPerSecond: 0))
                if existing.state == .suspended { existing.resume() }
                return
            }

            let task: URLSessionDownloadTask
            if let resumeData = try? Data(contentsOf: resumeURL), !resumeData.isEmpty {
                self.startedFromResumeData = true
                task = session.downloadTask(withResumeData: resumeData)
            } else {
                var request = URLRequest(url: url)
                request.timeoutInterval = 120
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
                task = session.downloadTask(with: request)
            }

            task.taskDescription = self.encodeMetadata(metadata)
            self.currentTaskIdentifier = task.taskIdentifier
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        lock.lock()
        let isCurrent = currentTaskIdentifier == downloadTask.taskIdentifier
        let handler = isCurrent ? progressHandler : nil
        let now = Date()
        let elapsed = max(now.timeIntervalSince(lastSampleDate), 0.001)
        let delta = max(totalBytesWritten - lastSampleBytes, 0)
        let speed = elapsed >= 0.4 ? Double(delta) / elapsed : 0
        if elapsed >= 0.4 {
            lastSampleDate = now
            lastSampleBytes = totalBytesWritten
        }
        lock.unlock()

        handler?(
            ProgressSnapshot(
                writtenBytes: max(totalBytesWritten, 0),
                expectedBytes: max(totalBytesExpectedToWrite, 0),
                bytesPerSecond: max(speed, 0)
            )
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let http = downloadTask.response as? HTTPURLResponse else {
            finish(.failure(DownloadError.invalidResponse), taskID: downloadTask.taskIdentifier)
            return
        }
        guard (200..<300).contains(http.statusCode) else {
            finish(.failure(DownloadError.httpStatus(http.statusCode)), taskID: downloadTask.taskIdentifier)
            return
        }

        guard let metadata = metadata(for: downloadTask) else {
            finish(.failure(DownloadError.unableToStoreFile), taskID: downloadTask.taskIdentifier)
            return
        }

        let destination = URL(fileURLWithPath: metadata.destinationPath)
        let resumeURL = URL(fileURLWithPath: metadata.resumeDataPath)

        do {
            let fm = FileManager.default
            try fm.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: location, to: destination)
            try? fm.removeItem(at: resumeURL)

            lock.lock()
            completedTaskIdentifiers.insert(downloadTask.taskIdentifier)
            lock.unlock()
        } catch {
            finish(.failure(error), taskID: downloadTask.taskIdentifier)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            let nsError = error as NSError
            let newResumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            let metadata = metadata(for: task)

            lock.lock()
            let isCurrent = currentTaskIdentifier == task.taskIdentifier
            let hadResumeData = isCurrent && startedFromResumeData
            lock.unlock()

            if let resumePath = metadata?.resumeDataPath {
                let resumeURL = URL(fileURLWithPath: resumePath)
                if let newResumeData, !newResumeData.isEmpty {
                    try? FileManager.default.createDirectory(
                        at: resumeURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try? newResumeData.write(to: resumeURL, options: Data.WritingOptions.atomic)
                } else if hadResumeData {
                    // A resume blob that immediately fails without replacement is stale.
                    try? FileManager.default.removeItem(at: resumeURL)
                }
            }

            finish(.failure(error), taskID: task.taskIdentifier)
            return
        }

        lock.lock()
        let completed = completedTaskIdentifiers.remove(task.taskIdentifier) != nil
        lock.unlock()

        if completed, let metadata = metadata(for: task) {
            finish(
                .success(URL(fileURLWithPath: metadata.destinationPath)),
                taskID: task.taskIdentifier
            )
        } else {
            finish(.failure(DownloadError.unableToStoreFile), taskID: task.taskIdentifier)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        lock.lock()
        let handler = backgroundCompletionHandler
        backgroundCompletionHandler = nil
        lock.unlock()
        handler?()
    }

    private func allTasks() async -> [URLSessionTask] {
        await withCheckedContinuation { continuation in
            session.getAllTasks { tasks in
                continuation.resume(returning: tasks)
            }
        }
    }

    private func matchingTask(for url: URL) async -> URLSessionDownloadTask? {
        let tasks = await allTasks()
        return tasks.compactMap { $0 as? URLSessionDownloadTask }.first { task in
            guard let metadata = metadata(for: task) else { return false }
            return metadata.sourceURL == url.absoluteString
                && task.state != .completed
                && task.state != .canceling
        }
    }

    private func metadata(for task: URLSessionTask) -> TransferMetadata? {
        if let description = task.taskDescription,
           let decoded = decodeMetadata(description) {
            return decoded
        }

        lock.lock()
        let fallback = currentTaskIdentifier == task.taskIdentifier ? currentMetadata : nil
        lock.unlock()
        return fallback
    }

    private func encodeMetadata(_ metadata: TransferMetadata) -> String? {
        guard let data = try? JSONEncoder().encode(metadata) else { return nil }
        return data.base64EncodedString()
    }

    private func decodeMetadata(_ text: String) -> TransferMetadata? {
        guard let data = Data(base64Encoded: text) else { return nil }
        return try? JSONDecoder().decode(TransferMetadata.self, from: data)
    }

    private func finish(_ result: Result<URL, Error>, taskID: Int) {
        lock.lock()
        guard currentTaskIdentifier == taskID, let continuation else {
            lock.unlock()
            return
        }

        self.continuation = nil
        self.progressHandler = nil
        self.currentTaskIdentifier = nil
        self.currentMetadata = nil
        self.lastSampleBytes = 0
        self.startedFromResumeData = false
        lock.unlock()

        switch result {
        case .success(let url):
            continuation.resume(returning: url)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
