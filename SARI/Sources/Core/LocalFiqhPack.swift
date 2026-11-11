import Foundation
import CryptoKit

struct FiqhPackManifest: Codable {
    let version: String
    let modelURL: URL
    let modelSHA256: String
    let modelBytes: Int64
    let libraryURL: URL
    let librarySHA256: String
    let libraryBytes: Int64
}

@MainActor
final class LocalFiqhPack: ObservableObject {
    static let shared = LocalFiqhPack()

    /// Keep the same verified 3B Q4_K_M model to preserve answer quality. v0.9.6
    /// changes runtime safety and download behavior, not the model weights.
    static let recommendedModelName = "Qwen2.5-3B Instruct Q4_K_M"
    static let recommendedModelURL = URL(
        string: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
    )!
    static let recommendedModelSHA256 = "626b4a6678b86442240e33df819e00132d3ba7dddfe1cdc4fbb18e0a9615c62d"
    static let recommendedModelVersion = "qwen2.5-3b-instruct-q4km-2026.09"
    static let recommendedApproxBytes: Int64 = 2_060_000_000

    /// Separate the model-file version from the runtime contract. Existing v0.9.5
    /// users can reuse the already verified 2.1 GB file; v0.9.6 only performs a
    /// quick model-load/inference self-test before enabling the assistant.
    static let runtimeValidationVersion = "swiftllama-0.1.0-sari-safe-v2"

    @Published private(set) var installed = false
    @Published private(set) var downloading = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var status = "غير مثبت"
    @Published private(set) var installedVersion: String?
    @Published private(set) var downloadedBytes: Int64 = 0
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var bytesPerSecond: Double = 0

    private let fm = FileManager.default

    private init() { refresh() }

    private var root: URL {
        fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SARI/FiqhAssistant", isDirectory: true)
    }

    var modelURL: URL { root.appendingPathComponent("model.gguf") }
    private var stagedModelURL: URL { root.appendingPathComponent("model.gguf.part") }
    private var resumeDataURL: URL { root.appendingPathComponent("model.gguf.resume") }

    private var writableLibraryURL: URL {
        root.appendingPathComponent("fiqh_pages.sqlite3")
    }

    private var bundledLibraryURL: URL? {
        Bundle.main.sariResourceURL(
            name: "fiqh_pages",
            extension: "sqlite3",
            subdirectory: "data"
        )
    }

    /// Prefer a verified downloaded library when present; otherwise use the bundled source DB.
    var libraryURL: URL {
        if fm.fileExists(atPath: writableLibraryURL.path) { return writableLibraryURL }
        return bundledLibraryURL ?? writableLibraryURL
    }

    var hasModel: Bool { fm.fileExists(atPath: modelURL.path) }

    private var versionURL: URL { root.appendingPathComponent("version.txt") }
    private var runtimeValidationURL: URL { root.appendingPathComponent("runtime-validation.txt") }

    private var runtimeValidationVersion: String? {
        (try? String(contentsOf: runtimeValidationURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var readyForInference: Bool {
        installed
            && hasModel
            && installedVersion == Self.recommendedModelVersion
            && runtimeValidationVersion == Self.runtimeValidationVersion
    }

    func refresh() {
        installed = fm.fileExists(atPath: libraryURL.path)
        installedVersion = (try? String(contentsOf: versionURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if installed {
            if readyForInference {
                status = "جاهز للعمل محليًا بالنموذج والنصوص"
            } else if hasModel && installedVersion == Self.recommendedModelVersion {
                status = "النموذج مثبت — يلزم فحص توافق سريع قبل التشغيل"
            } else if hasModel {
                status = "يتوفر نموذج قديم — يلزم تحديث النموذج المحلي"
            } else if fm.fileExists(atPath: stagedModelURL.path) {
                status = "اكتمل التنزيل — بانتظار التحقق والتفعيل"
            } else {
                status = "النصوص جاهزة — نزّل النموذج المحلي مرة واحدة"
            }
        } else {
            status = "تعذر تجهيز النصوص المحلية"
        }
    }

    func remove() throws {
        if fm.fileExists(atPath: root.path) { try fm.removeItem(at: root) }
        installedVersion = nil
        progress = 0
        downloadedBytes = 0
        totalBytes = 0
        bytesPerSecond = 0
        refresh()
        Task { await LocalFiqhEngine.shared.releaseModelIfIdle() }
    }

    /// If iOS continued the large background transfer while SARI was suspended or
    /// relaunched, reattach to it when the app becomes active. A completed staged
    /// file is verified/activated here rather than downloaded again.
    func resumeBackgroundWorkIfNeeded() async {
        guard installed, !readyForInference, !downloading else { return }
        let hasStaged = fm.fileExists(atPath: stagedModelURL.path)
        let active = await ResumableFileDownloader.shared.hasActiveDownload(
            from: Self.recommendedModelURL
        )
        guard hasStaged || active else { return }

        do {
            try await installRecommendedModel()
        } catch {
            status = "تعذر إكمال التحقق من التنزيل — يمكن إعادة المحاولة"
            await SariDiagnostics.shared.log(
                "fiqh.pack.resume error=\(String(describing: error))"
            )
        }
    }

    /// One-tap install for SARI's validated offline multilingual model.
    /// The bundled fiqh database stays inside the app; only the GGUF is downloaded.
    func installRecommendedModel() async throws {
        guard !downloading else { return }
        guard installed else { throw URLError(.fileDoesNotExist) }

        downloading = true
        progress = 0.02
        bytesPerSecond = 0
        defer { downloading = false }

        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        // Reuse a model already verified by v0.9.5. The runtime marker is intentionally
        // new, so the first v0.9.6 use still exercises SwiftLlama with a tiny safe prompt.
        if hasModel && installedVersion == Self.recommendedModelVersion {
            status = "فحص توافق النموذج المثبت…"
            progress = 0.94
            try await validateRuntimeAndMarkReady()
            return
        }

        // A background URLSession may have completed while the process was suspended.
        // Verify its staged file before deciding to start another 2.1 GB transfer.
        if fm.fileExists(atPath: stagedModelURL.path) {
            status = "التحقق من التنزيل المكتمل…"
            progress = 0.90
            if try verifyRecommendedStagedModel() {
                try activateRecommendedStagedModel()
                try await validateRuntimeAndMarkReady()
                return
            }
            try? fm.removeItem(at: stagedModelURL)
            try? fm.removeItem(at: resumeDataURL)
        }

        let values = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let free = values.volumeAvailableCapacityForImportantUsage,
           free < 3_200_000_000 {
            throw URLError(.dataLengthExceedsMaximum)
        }

        downloadedBytes = 0
        totalBytes = Self.recommendedApproxBytes
        progress = 0.08

        var lastError: Error?
        for attempt in 1...3 {
            do {
                try await fetch(
                    Self.recommendedModelURL,
                    to: stagedModelURL,
                    resumeDataAt: resumeDataURL,
                    expectedBytes: 0,
                    sha256: Self.recommendedModelSHA256,
                    base: 0.08,
                    span: 0.82,
                    label: attempt == 1
                        ? "تنزيل نموذج المساعد في الخلفية…"
                        : "استكمال تنزيل النموذج — المحاولة \(attempt) من 3…"
                )
                lastError = nil
                break
            } catch {
                lastError = error
                guard attempt < 3 else { break }
                status = "انقطع الاتصال — سيحاول SARI الاستكمال تلقائيًا…"
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
            }
        }

        if let lastError { throw lastError }

        try activateRecommendedStagedModel()
        try await validateRuntimeAndMarkReady()
    }

    private func activateRecommendedStagedModel() throws {
        status = "تفعيل النموذج بعد التحقق…"
        try atomicReplace(stagedModelURL, modelURL)
        try? fm.removeItem(at: resumeDataURL)
        try? fm.removeItem(at: runtimeValidationURL)
        try Self.recommendedModelVersion.write(
            to: versionURL,
            atomically: true,
            encoding: .utf8
        )
        installedVersion = Self.recommendedModelVersion
        progress = max(progress, 0.94)
    }

    private func verifyRecommendedStagedModel() throws -> Bool {
        let attrs = try fm.attributesOfItem(atPath: stagedModelURL.path)
        let bytes = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        guard bytes > 1_500_000_000 else { return false }
        downloadedBytes = bytes
        totalBytes = max(totalBytes, Self.recommendedApproxBytes)
        let digest = try sha256File(stagedModelURL)
        return digest.caseInsensitiveCompare(Self.recommendedModelSHA256) == .orderedSame
    }

    private func validateRuntimeAndMarkReady() async throws {
        try? fm.removeItem(at: runtimeValidationURL)
        status = "اختبار تشغيل النموذج محليًا…"
        progress = max(progress, 0.97)

        do {
            try await LocalFiqhEngine.shared.validateRuntime(modelURL: modelURL)
            try Self.runtimeValidationVersion.write(
                to: runtimeValidationURL,
                atomically: true,
                encoding: .utf8
            )
            try? fm.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: runtimeValidationURL.path
            )
            progress = 1
            status = "جاهز للعمل بدون إنترنت"
            refresh()
            await SariDiagnostics.shared.log("fiqh.pack runtimeValidation=passed")
        } catch {
            try? fm.removeItem(at: runtimeValidationURL)
            status = "فشل فحص تشغيل النموذج — لم يتم تفعيل المساعد"
            refresh()
            await SariDiagnostics.shared.log(
                "fiqh.pack runtimeValidation=failed error=\(String(describing: error))"
            )
            throw error
        }
    }

    /// Keeps compatibility with a future signed manifest hosted by the project.
    func install(from manifestURL: URL) async throws {
        guard !downloading else { return }
        downloading = true
        progress = 0
        status = "جلب معلومات الحزمة…"
        defer { downloading = false }

        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        guard manifestURL.scheme?.lowercased() == "https" else {
            throw URLError(.secureConnectionFailed)
        }

        let values = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let free = values.volumeAvailableCapacityForImportantUsage,
           free < 3_000_000_000 {
            throw URLError(.dataLengthExceedsMaximum)
        }

        let (manifestData, response) = try await URLSession.shared.data(from: manifestURL)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let manifest = try JSONDecoder().decode(FiqhPackManifest.self, from: manifestData)
        guard manifest.modelURL.scheme?.lowercased() == "https",
              manifest.libraryURL.scheme?.lowercased() == "https" else {
            throw URLError(.secureConnectionFailed)
        }
        guard manifest.modelBytes > 0, manifest.libraryBytes > 0 else {
            throw URLError(.cannotParseResponse)
        }

        let stagedModel = root.appendingPathComponent("manifest-model.gguf.part")
        let stagedLibrary = root.appendingPathComponent("fiqh_pages.sqlite3.part")
        try? fm.removeItem(at: runtimeValidationURL)

        do {
            try await fetch(
                manifest.modelURL,
                to: stagedModel,
                resumeDataAt: root.appendingPathComponent("manifest-model.resume"),
                expectedBytes: manifest.modelBytes,
                sha256: manifest.modelSHA256,
                base: 0,
                span: 0.82,
                label: "تنزيل نموذج المساعد…"
            )
            try await fetch(
                manifest.libraryURL,
                to: stagedLibrary,
                resumeDataAt: root.appendingPathComponent("manifest-library.resume"),
                expectedBytes: manifest.libraryBytes,
                sha256: manifest.librarySHA256,
                base: 0.82,
                span: 0.18,
                label: "تنزيل مكتبة النصوص…"
            )

            try atomicReplace(stagedModel, modelURL)
            try atomicReplace(stagedLibrary, writableLibraryURL)
            try manifest.version.write(to: versionURL, atomically: true, encoding: .utf8)
        } catch {
            throw error
        }

        progress = 1
        installedVersion = manifest.version
        status = "تم تثبيت الحزمة"
        refresh()
    }

    private func fetch(
        _ url: URL,
        to destination: URL,
        resumeDataAt resumeDataURL: URL,
        expectedBytes: Int64,
        sha256: String,
        base: Double,
        span: Double,
        label: String
    ) async throws {
        guard url.scheme?.lowercased() == "https" else {
            throw URLError(.secureConnectionFailed)
        }

        status = label
        let downloaded = try await ResumableFileDownloader.shared.download(
            from: url,
            to: destination,
            resumeDataAt: resumeDataURL
        ) { snapshot in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.downloadedBytes = snapshot.writtenBytes
                let effectiveTotal = snapshot.expectedBytes > 0 ? snapshot.expectedBytes : self.totalBytes
                if snapshot.expectedBytes > 0 { self.totalBytes = snapshot.expectedBytes }
                if effectiveTotal > 0 {
                    let fraction = min(1, Double(snapshot.writtenBytes) / Double(effectiveTotal))
                    self.progress = min(0.91, base + span * fraction)
                }
                self.bytesPerSecond = snapshot.bytesPerSecond
            }
        }

        let attrs = try fm.attributesOfItem(atPath: downloaded.path)
        let bytes = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        downloadedBytes = bytes
        if expectedBytes > 0 { totalBytes = expectedBytes }
        guard expectedBytes <= 0 || bytes == expectedBytes else {
            try? fm.removeItem(at: downloaded)
            try? fm.removeItem(at: resumeDataURL)
            throw URLError(.cannotDecodeContentData)
        }

        status = "التحقق من SHA‑256…"
        progress = max(progress, base + span * 0.96)
        let digest = try sha256File(downloaded)
        guard digest.caseInsensitiveCompare(sha256) == .orderedSame else {
            try? fm.removeItem(at: downloaded)
            try? fm.removeItem(at: resumeDataURL)
            throw URLError(.cannotDecodeContentData)
        }

        try? fm.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: downloaded.path
        )
        progress = min(0.94, base + span)
    }

    /// Incremental SHA-256 avoids loading a multi-gigabyte model into RAM.
    private func sha256File(_ url: URL) throws -> String {
        guard let stream = InputStream(url: url) else { throw URLError(.cannotOpenFile) }
        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        let bufferSize = 1024 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeContentData) }
            if count == 0 { break }
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: count))
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func atomicReplace(_ source: URL, _ destination: URL) throws {
        if fm.fileExists(atPath: destination.path) {
            _ = try fm.replaceItemAt(
                destination,
                withItemAt: source,
                backupItemName: nil,
                options: []
            )
        } else {
            try fm.moveItem(at: source, to: destination)
        }

        try? fm.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: destination.path
        )
    }
}
