import Foundation

/// A single-file downloader intended for very large optional assets such as GGUF models.
/// It persists URLSession resume data after transient failures so the next attempt can
/// continue instead of restarting a multi-gigabyte transfer from zero.
final class ResumableFileDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let shared = ResumableFileDownloader()

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

    private let lock = NSLock()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 6 * 60 * 60
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private var continuation: CheckedContinuation<URL, Error>?
    private var progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
    private var destinationURL: URL?
    private var resumeDataURL: URL?
    private var lastSampleDate = Date()
    private var lastSampleBytes: Int64 = 0
    private var completedResult = false
    private var startedFromResumeData = false

    private override init() {
        super.init()
    }

    func download(
        from url: URL,
        to destination: URL,
        resumeDataAt resumeURL: URL,
        progress: @escaping @Sendable (ProgressSnapshot) -> Void
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            defer { lock.unlock() }

            guard self.continuation == nil else {
                continuation.resume(throwing: DownloadError.busy)
                return
            }

            self.continuation = continuation
            self.progressHandler = progress
            self.destinationURL = destination
            self.resumeDataURL = resumeURL
            self.lastSampleDate = Date()
            self.lastSampleBytes = 0
            self.completedResult = false

            let task: URLSessionDownloadTask
            if let resumeData = try? Data(contentsOf: resumeURL), !resumeData.isEmpty {
                self.startedFromResumeData = true
                task = session.downloadTask(withResumeData: resumeData)
            } else {
                self.startedFromResumeData = false
                var request = URLRequest(url: url)
                request.timeoutInterval = 120
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
                task = session.downloadTask(with: request)
            }
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
        let handler = progressHandler
        let now = Date()
        let elapsed = max(now.timeIntervalSince(lastSampleDate), 0.001)
        let delta = max(totalBytesWritten - lastSampleBytes, 0)
        let speed = Double(delta) / elapsed
        if elapsed >= 0.4 {
            lastSampleDate = now
            lastSampleBytes = totalBytesWritten
        }
        lock.unlock()

        handler?(
            ProgressSnapshot(
                writtenBytes: max(totalBytesWritten, 0),
                expectedBytes: max(totalBytesExpectedToWrite, 0),
                bytesPerSecond: speed
            )
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let http = downloadTask.response as? HTTPURLResponse else {
            finish(.failure(DownloadError.invalidResponse))
            return
        }
        guard (200..<300).contains(http.statusCode) else {
            finish(.failure(DownloadError.httpStatus(http.statusCode)))
            return
        }

        lock.lock()
        let destination = destinationURL
        let resumeURL = resumeDataURL
        lock.unlock()

        guard let destination else {
            finish(.failure(DownloadError.unableToStoreFile))
            return
        }

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
            if let resumeURL { try? fm.removeItem(at: resumeURL) }
            lock.lock()
            completedResult = true
            lock.unlock()
        } catch {
            finish(.failure(error))
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

            lock.lock()
            let resumeURL = resumeDataURL
            let hadResumeData = startedFromResumeData
            lock.unlock()

            if let newResumeData, !newResumeData.isEmpty, let resumeURL {
                try? FileManager.default.createDirectory(
                    at: resumeURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? newResumeData.write(to: resumeURL, options: Data.WritingOptions.atomic)
            } else if hadResumeData, let resumeURL {
                // If a resume-based task fails without producing replacement resume data,
                // the stored resume blob is stale/corrupt. Remove it so the next retry can
                // start a clean request instead of failing forever on the same blob.
                try? FileManager.default.removeItem(at: resumeURL)
            }

            finish(.failure(error))
            return
        }

        lock.lock()
        let destination = destinationURL
        let success = completedResult
        lock.unlock()

        if success, let destination {
            finish(.success(destination))
        } else {
            finish(.failure(DownloadError.unableToStoreFile))
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        self.progressHandler = nil
        self.destinationURL = nil
        self.resumeDataURL = nil
        self.completedResult = false
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
