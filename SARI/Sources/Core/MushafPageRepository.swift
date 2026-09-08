import Foundation

/// Provides page-accurate Madinah Mushaf artwork (Hafs, KFQC layout).
/// A page is loaded from the app bundle when present, otherwise from a trusted HTTPS mirror,
/// then cached in Application Support so it remains available offline after the first load.
actor MushafPageRepository {
    static let shared = MushafPageRepository()

    private let fileManager = FileManager.default
    private let validPages = 1...604
    private var memoryCache: [Int: Data] = [:]
    private var memoryOrder: [Int] = []
    private let memoryLimit = 7

    private var cacheDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SARI/Mushaf/Hafs-KFQC", isDirectory: true)
    }

    func svgData(for page: Int) async throws -> Data {
        guard validPages.contains(page) else { throw URLError(.badURL) }

        if let cached = memoryCache[page] { return cached }

        if let bundled = bundledPageData(page), isValidSVG(bundled) {
            remember(bundled, page: page)
            return bundled
        }

        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let destination = cacheDirectory.appendingPathComponent(String(format: "%03d.svg", page))

        if let cached = try? Data(contentsOf: destination), isValidSVG(cached) {
            remember(cached, page: page)
            return cached
        }

        var lastError: Error = URLError(.cannotLoadFromNetwork)
        for url in sourceURLs(page: page) {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 35
                request.cachePolicy = .reloadRevalidatingCacheData
                request.setValue("image/svg+xml,text/xml;q=0.9,*/*;q=0.1", forHTTPHeaderField: "Accept")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      isValidSVG(data) else {
                    throw URLError(.cannotDecodeContentData)
                }

                try data.write(to: destination, options: .atomic)
                try? fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: destination.path
                )
                remember(data, page: page)
                return data
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    func prefetch(pages: [Int]) async {
        for page in pages where validPages.contains(page) {
            _ = try? await svgData(for: page)
        }
    }

    func isCached(_ page: Int) -> Bool {
        guard validPages.contains(page) else { return false }
        if memoryCache[page] != nil || bundledPageData(page) != nil { return true }
        let path = cacheDirectory.appendingPathComponent(String(format: "%03d.svg", page)).path
        return fileManager.fileExists(atPath: path)
    }

    private func bundledPageData(_ page: Int) -> Data? {
        let name = String(format: "%03d", page)
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "svg",
            subdirectory: "mushaf/hafs-kfqc"
        ) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func sourceURLs(page: Int) -> [URL] {
        let padded = String(format: "%03d", page)
        return [
            URL(string: "https://raw.githubusercontent.com/quranpedia/quran-svg/main/mushafs/hafs/kfqc/svg/\(padded).svg")!,
            URL(string: "https://cdn.jsdelivr.net/gh/quranpedia/quran-svg@main/mushafs/hafs/kfqc/svg/\(padded).svg")!
        ]
    }

    private func remember(_ data: Data, page: Int) {
        memoryCache[page] = data
        memoryOrder.removeAll { $0 == page }
        memoryOrder.append(page)
        while memoryOrder.count > memoryLimit {
            let removed = memoryOrder.removeFirst()
            memoryCache.removeValue(forKey: removed)
        }
    }

    private func isValidSVG(_ data: Data) -> Bool {
        guard data.count > 1_000,
              let head = String(data: data.prefix(16_384), encoding: .utf8)?.lowercased() else {
            return false
        }
        return head.contains("<svg") && head.contains("viewbox")
    }
}
