import Foundation

/// Small local technical log used only to diagnose failures that would otherwise
/// be silent on-device. It deliberately records no question or answer text.
actor SariDiagnostics {
    static let shared = SariDiagnostics()

    private let fileManager = FileManager.default
    private let maxBytes = 256 * 1024

    private var logURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SARI/Diagnostics", isDirectory: true)
        return base.appendingPathComponent("runtime.log")
    }

    func log(_ event: String) {
        do {
            let url = logURL
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let stamp = ISO8601DateFormatter().string(from: Date())
            let line = "\(stamp) \(event)\n"
            let data = Data(line.utf8)

            if fileManager.fileExists(atPath: url.path) {
                if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                   let size = (attrs[.size] as? NSNumber)?.intValue,
                   size > maxBytes {
                    try? fileManager.removeItem(at: url)
                }
            }

            if !fileManager.fileExists(atPath: url.path) {
                try data.write(to: url, options: .atomic)
            } else if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            }
        } catch {
            // Diagnostics must never become a reason for the app to fail.
        }
    }
}
