import Foundation

struct FiqhSource: Codable, Identifiable {
    let id: Int
    let part: Int
    let page: Int
    let text: String
    let pdf_file: String
    let source_label: String
    let score: Double?
    let pdf_url: String?
}

struct FiqhServerAnswer: Codable {
    let level: String
    let answer: String
    let reason: String?
    let retrieval_confidence: Int
    let confidence_label: String
    let sources: [FiqhSource]
    let contact_scholar_recommended: Bool
    let ai_enabled: Bool?
    let source_basis: String?
    let disclaimer: String
}

enum SariAPIConfig {
    static var baseURL: URL? {
        guard let raw = Bundle.main.object(
            forInfoDictionaryKey: "SARI_API_BASE_URL"
        ) as? String else {
            return nil
        }

        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(
                in: CharacterSet(charactersIn: "/")
            )

        guard !clean.isEmpty,
              !clean.contains("YOUR-") else {
            return nil
        }

        guard let url = URL(string: clean) else {
            return nil
        }

        #if DEBUG
        return url
        #else
        guard url.scheme == "https" else {
            return nil
        }
        return url
        #endif
    }
}

@MainActor
final class FiqhAPI {

    static let shared = FiqhAPI()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral

        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 150
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        session = URLSession(configuration: configuration)
    }

    var isConfigured: Bool {
        SariAPIConfig.baseURL != nil
    }

    func absoluteSourceURL(_ source: FiqhSource) -> URL? {
        guard let relative = source.pdf_url,
              let base = SariAPIConfig.baseURL else {
            return nil
        }

        if let direct = URL(string: relative),
           direct.scheme != nil {
            return direct
        }

        return URL(
            string: relative,
            relativeTo: base
        )?.absoluteURL
    }

    func ask(
        question: String,
        language: String =
            Locale.current.language.languageCode?.identifier ?? "ar"
    ) async throws -> FiqhServerAnswer {

        guard let base = SariAPIConfig.baseURL,
              let url = URL(
                string: "/fiqh/ask",
                relativeTo: base
              )?.absoluteURL else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)

        request.httpMethod = "POST"

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        request.setValue(
            "SARI-iOS/0.8",
            forHTTPHeaderField: "User-Agent"
        )

        request.httpBody = try JSONEncoder().encode([
            "question": question,
            "language": language
        ])

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(
            FiqhServerAnswer.self,
            from: data
        )
    }
}