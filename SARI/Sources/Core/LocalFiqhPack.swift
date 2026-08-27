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

    @Published private(set) var installed = false
    @Published private(set) var downloading = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var status = "غير مثبت"
    @Published private(set) var installedVersion: String?

    private let fm = FileManager.default

    private init() {
        refresh()
    }

    private var root: URL {
        let base = fm.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return base.appendingPathComponent(
            "SARI/FiqhAssistant",
            isDirectory: true
        )
    }

    var modelURL: URL {
        root.appendingPathComponent("model.gguf")
    }

    private var writableLibraryURL: URL {
        root.appendingPathComponent("fiqh_pages.sqlite3")
    }

    private var bundledLibraryURL: URL? {
        Bundle.main.sariResourceURL(name: "fiqh_pages", extension: "sqlite3", subdirectory: "data")
    }

    /// Prefer a verified downloaded library when present; otherwise read the bundled source database directly.
    /// This avoids copying a large database on first launch.
    var libraryURL: URL {
        if fm.fileExists(atPath: writableLibraryURL.path) { return writableLibraryURL }
        return bundledLibraryURL ?? writableLibraryURL
    }

    var hasModel: Bool {
        fm.fileExists(atPath: modelURL.path)
    }

    private var versionURL: URL {
        root.appendingPathComponent("version.txt")
    }

    func refresh() {
        installed = fm.fileExists(atPath: libraryURL.path)

        installedVersion = (try? String(contentsOf: versionURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if installed {
            status = hasModel
                ? "جاهز للعمل محليًا بالنموذج والمصادر"
                : "المصادر الفقهية المحلية جاهزة"
        } else {
            status = "تعذر تجهيز المصادر المحلية"
        }
    }

    func remove() throws {
        if fm.fileExists(atPath: root.path) {
            try fm.removeItem(at: root)
        }

        installedVersion = nil
        progress = 0
        refresh()
    }

    func install(
        from manifestURL: URL
    ) async throws {

        guard !downloading else {
            return
        }

        downloading = true
        progress = 0
        status = "جلب معلومات الحزمة…"

        defer {
            downloading = false
        }

        try fm.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        guard manifestURL.scheme?.lowercased() == "https" else {
            throw URLError(.secureConnectionFailed)
        }

        let values = try root.resourceValues(
            forKeys: [
                .volumeAvailableCapacityForImportantUsageKey
            ]
        )

        if let free =
            values.volumeAvailableCapacityForImportantUsage,
           free < 3_000_000_000 {
            throw URLError(.dataLengthExceedsMaximum)
        }

        let (manifestData, response) =
            try await URLSession.shared.data(
                from: manifestURL
            )

        guard let http =
                response as? HTTPURLResponse,
              (200..<300).contains(
                http.statusCode
              ) else {
            throw URLError(.badServerResponse)
        }

        let manifest =
            try JSONDecoder().decode(
                FiqhPackManifest.self,
                from: manifestData
            )

        guard
            manifest.modelURL.scheme?.lowercased()
                == "https",
            manifest.libraryURL.scheme?.lowercased()
                == "https"
        else {
            throw URLError(.secureConnectionFailed)
        }

        guard
            manifest.modelBytes > 0,
            manifest.libraryBytes > 0
        else {
            throw URLError(.cannotParseResponse)
        }

        let stagedModel =
            root.appendingPathComponent(
                "model.gguf.new"
            )

        let stagedLibrary =
            root.appendingPathComponent(
                "fiqh_pages.sqlite3.new"
            )

        try? fm.removeItem(
            at: stagedModel
        )

        try? fm.removeItem(
            at: stagedLibrary
        )

        do {
            try await fetch(
                manifest.modelURL,
                to: stagedModel,
                expectedBytes:
                    manifest.modelBytes,
                sha256:
                    manifest.modelSHA256,
                base: 0,
                span: 0.82,
                label:
                    "تنزيل نموذج المساعد…"
            )

            try await fetch(
                manifest.libraryURL,
                to: stagedLibrary,
                expectedBytes:
                    manifest.libraryBytes,
                sha256:
                    manifest.librarySHA256,
                base: 0.82,
                span: 0.18,
                label:
                    "تنزيل مكتبة المصادر…"
            )

            try atomicReplace(
                stagedModel,
                modelURL
            )

            try atomicReplace(
                stagedLibrary,
                writableLibraryURL
            )

            try manifest.version.write(
                to: versionURL,
                atomically: true,
                encoding: .utf8
            )

        } catch {
            try? fm.removeItem(
                at: stagedModel
            )

            try? fm.removeItem(
                at: stagedLibrary
            )

            throw error
        }

        progress = 1
        installed = true
        installedVersion =
            manifest.version
        status =
            "جاهز للعمل بدون إنترنت"
    }

    private func fetch(
        _ url: URL,
        to destination: URL,
        expectedBytes: Int64,
        sha256: String,
        base: Double,
        span: Double,
        label: String
    ) async throws {

        status = label

        let (temp, response) =
            try await URLSession.shared.download(
                from: url
            )

        guard let http =
                response as? HTTPURLResponse,
              (200..<300).contains(
                http.statusCode
              ) else {
            throw URLError(.badServerResponse)
        }

        let attrs =
            try fm.attributesOfItem(
                atPath: temp.path
            )

        let bytes =
            (attrs[.size] as? NSNumber)?
                .int64Value ?? 0

        guard
            expectedBytes <= 0
            || bytes == expectedBytes
        else {
            throw URLError(
                .cannotDecodeContentData
            )
        }

        let digest =
            try sha256File(temp)

        guard
            digest.caseInsensitiveCompare(
                sha256
            ) == .orderedSame
        else {
            throw URLError(
                .cannotDecodeContentData
            )
        }

        if fm.fileExists(
            atPath: destination.path
        ) {
            try fm.removeItem(
                at: destination
            )
        }

        try fm.moveItem(
            at: temp,
            to: destination
        )

        try? fm.setAttributes(
            [
                .protectionKey:
                    FileProtectionType
                        .completeUntilFirstUserAuthentication
            ],
            ofItemAtPath:
                destination.path
        )

        progress =
            min(
                1,
                base + span
            )
    }

    private func sha256File(
        _ url: URL
    ) throws -> String {

        let data =
            try Data(
                contentsOf: url,
                options: .mappedIfSafe
            )

        return SHA256
            .hash(data: data)
            .map {
                String(
                    format: "%02x",
                    $0
                )
            }
            .joined()
    }

    private func atomicReplace(
        _ source: URL,
        _ destination: URL
    ) throws {

        if fm.fileExists(
            atPath: destination.path
        ) {
            _ = try fm.replaceItemAt(
                destination,
                withItemAt: source,
                backupItemName: nil,
                options: []
            )
        } else {
            try fm.moveItem(
                at: source,
                to: destination
            )
        }

        try? fm.setAttributes(
            [
                .protectionKey:
                    FileProtectionType
                        .completeUntilFirstUserAuthentication
            ],
            ofItemAtPath:
                destination.path
        )
    }
}