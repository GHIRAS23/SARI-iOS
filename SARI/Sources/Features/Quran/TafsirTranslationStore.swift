import Foundation
import Combine
import CryptoKit

struct TafsirTranslationEntry: Codable {
    let id: Int
    let text: String
}

/// manifest.json published next to every pack (created by scripts/build_tafsir_packs.py).
struct TafsirPackManifest: Codable {
    let language: String
    let version: String
    let entries: Int
    let sha256: String
    let bytes: Int64
    let file: String
    let source: String
}

enum TafsirPackError: Error {
    case notConfigured
    case badManifest
    case badResponse
    case checksumMismatch
    case invalidContent
}

/// Stores downloadable verse-meaning packs (one file per language, 6,236 entries each).
/// The Arabic tafsir itself is bundled and never depends on this store.
@MainActor
final class TafsirTranslationStore: ObservableObject {
    static let ayahCount = 6_236
    static let packCodes = ["en", "tr", "ms", "id", "ja", "zh", "ru", "fr"]

    enum PackState: Equatable {
        case notInstalled
        case downloading
        case installed
        case failed
    }

    @Published private(set) var packStates: [String: PackState] = [:]
    @Published private(set) var englishMeanings: [Int: String] = [:]
    @Published private(set) var languageMeanings: [Int: String] = [:]
    @Published private(set) var aiTranslation: String?
    @Published private(set) var isTranslatingWithAI = false
    @Published private(set) var aiTranslationFailed = false

    private(set) var currentLanguage: SariLanguage = .ar
    private var generatedTranslations: [String: [Int: String]] = [:]
    private let fileManager = FileManager.default
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 600
        return URLSession(configuration: configuration)
    }()

    init() {
        refreshEnglish()
    }

    // MARK: - Locations and configuration

    static var packDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SARI/TafsirPacks", isDirectory: true)
    }

    static var generatedDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SARI/GeneratedQuranMeanings", isDirectory: true)
    }

    static func fileURL(for code: String) -> URL {
        packDirectory.appendingPathComponent("\(code).json")
    }

    /// Base HTTPS address where the packs are hosted, from Info.plist (SARI_TAFSIR_PACK_BASE_URL).
    /// Returns nil while the value is still the placeholder, so the app never calls a fake host.
    static var packBaseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SARI_TAFSIR_PACK_BASE_URL") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !trimmed.contains("YOUR-"),
              let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https" else {
            return nil
        }
        return url
    }

    var isDownloadConfigured: Bool { Self.packBaseURL != nil }

    func packState(for code: String) -> PackState {
        packStates[code] ?? .notInstalled
    }

    // MARK: - Loading installed packs (never touches the network)

    /// Called when the sheet opens for an ayah. Reads only files already on the device.
    func load(_ language: SariLanguage) {
        currentLanguage = language
        aiTranslation = nil
        aiTranslationFailed = false
        refreshEnglish()

        languageMeanings = [:]
        guard language != .ar, language != .en else { return }

        let code = language.rawValue
        if let meanings = try? Self.readMeanings(at: Self.fileURL(for: code)) {
            languageMeanings = meanings
            packStates[code] = .installed
        } else if packStates[code] != .downloading {
            packStates[code] = .notInstalled
        }
        generatedTranslations[code] = loadGeneratedTranslations(code)
    }

    private func refreshEnglish() {
        guard packStates["en"] != .downloading else { return }
        if let meanings = try? Self.readMeanings(at: Self.fileURL(for: "en")) {
            englishMeanings = meanings
            packStates["en"] = .installed
        } else {
            englishMeanings = [:]
            packStates["en"] = .notInstalled
        }
    }

    func englishMeaning(for ayah: Ayah) -> String? {
        englishMeanings[ayah.id]
    }

    func languageMeaning(for ayah: Ayah) -> String? {
        languageMeanings[ayah.id]
    }

    // MARK: - Downloading and verifying packs

    /// Downloads a pack once, verifies its SHA-256 and content, then stores it for offline use.
    func downloadPack(_ code: String) async {
        guard Self.packCodes.contains(code) else { return }
        guard let base = Self.packBaseURL else {
            packStates[code] = .failed
            return
        }
        guard NetworkState.shared.online else {
            packStates[code] = .failed
            return
        }

        packStates[code] = .downloading
        do {
            let manifestURL = base
                .appendingPathComponent(code, isDirectory: true)
                .appendingPathComponent("manifest.json")
            let (manifestData, manifestResponse) = try await session.data(from: manifestURL)
            try Self.checkHTTP(manifestResponse)

            let manifest = try JSONDecoder().decode(TafsirPackManifest.self, from: manifestData)
            guard manifest.language == code,
                  manifest.entries == Self.ayahCount,
                  manifest.sha256.count == 64,
                  manifest.file.hasSuffix(".json"),
                  !manifest.file.contains("/") else {
                throw TafsirPackError.badManifest
            }

            let fileURL = manifestURL.deletingLastPathComponent().appendingPathComponent(manifest.file)
            let (tempURL, fileResponse) = try await session.download(from: fileURL)
            try Self.checkHTTP(fileResponse)
            let data = try Data(contentsOf: tempURL)

            try install(data: data, language: code, sha256: manifest.sha256)
            packStates[code] = .installed
            if code == "en" || code == currentLanguage.rawValue {
                load(currentLanguage)
            }
        } catch {
            packStates[code] = .failed
        }
    }

    func install(data: Data, language code: String, sha256: String) throws {
        guard Self.packCodes.contains(code) else { throw TafsirPackError.badManifest }

        let digest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        guard digest == sha256.lowercased() else { throw TafsirPackError.checksumMismatch }

        let rows = try JSONDecoder().decode([TafsirTranslationEntry].self, from: data)
        try Self.validate(rows)

        try fileManager.createDirectory(at: Self.packDirectory, withIntermediateDirectories: true)
        let destination = Self.fileURL(for: code)
        try data.write(to: destination, options: .atomic)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: destination.path
        )
    }

    // MARK: - Optional on-device AI translation (fallback only, never required)

    /// Translates the English meaning of one verse with the installed local model.
    /// Used only when no reviewed pack exists for the selected language.
    func translateWithLocalModel(for ayah: Ayah) async {
        let language = currentLanguage
        guard language != .ar, language != .en else { return }
        guard let source = englishMeanings[ayah.id] else { return }

        if let cached = generatedTranslations[language.rawValue]?[ayah.id] {
            aiTranslation = cached
            return
        }
        guard LocalFiqhPack.shared.readyForInference else {
            aiTranslationFailed = true
            return
        }

        isTranslatingWithAI = true
        aiTranslationFailed = false
        aiTranslation = nil
        defer { isTranslatingWithAI = false }

        do {
            let translated = try await LocalFiqhEngine.shared.translateEnglishVerseMeaning(source, into: language)
            generatedTranslations[language.rawValue, default: [:]][ayah.id] = translated
            try saveGeneratedTranslations(for: language.rawValue)
            aiTranslation = translated
        } catch {
            aiTranslationFailed = true
        }
    }

    // MARK: - Helpers

    private static func readMeanings(at url: URL) throws -> [Int: String] {
        let data = try Data(contentsOf: url)
        let rows = try JSONDecoder().decode([TafsirTranslationEntry].self, from: data)
        try validate(rows)
        var result: [Int: String] = [:]
        for row in rows {
            result[row.id] = row.text
        }
        return result
    }

    private static func validate(_ rows: [TafsirTranslationEntry]) throws {
        guard rows.count == ayahCount,
              Set(rows.map(\.id)) == Set(1...ayahCount),
              rows.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw TafsirPackError.invalidContent
        }
    }

    private static func checkHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw TafsirPackError.badResponse
        }
    }

    private func loadGeneratedTranslations(_ code: String) -> [Int: String] {
        let url = Self.generatedDirectory.appendingPathComponent("\(code).json")
        guard let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([TafsirTranslationEntry].self, from: data) else {
            return [:]
        }
        var result: [Int: String] = [:]
        for row in rows where row.id > 0 && !row.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result[row.id] = row.text
        }
        return result
    }

    private func saveGeneratedTranslations(for code: String) throws {
        try fileManager.createDirectory(at: Self.generatedDirectory, withIntermediateDirectories: true)
        let rows = (generatedTranslations[code] ?? [:])
            .map { TafsirTranslationEntry(id: $0.key, text: $0.value) }
            .sorted { $0.id < $1.id }
        let destination = Self.generatedDirectory.appendingPathComponent("\(code).json")
        try JSONEncoder().encode(rows).write(to: destination, options: .atomic)
    }
}
