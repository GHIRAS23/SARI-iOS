import Foundation
import Combine

struct ExchangeRatePayload: Decodable {
    let result: String?
    let base_code: String
    let time_last_update_unix: Int?
    let rates: [String: Double]
}

struct CachedExchangeRates: Codable {
    let baseCode: String
    let rates: [String: Double]
    let updatedAt: Date
    let provider: String
}

enum CurrencyRateError: LocalizedError {
    case invalidResponse
    case providerRejected
    case missingRate

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The exchange-rate service returned an invalid response."
        case .providerRejected: return "The exchange-rate service did not return a successful result."
        case .missingRate: return "The selected currency rate is not available."
        }
    }
}

@MainActor
final class CurrencyConverterStore: ObservableObject {
    @Published var amount = "1"
    @Published var baseCurrency = "SAR"
    @Published var targetCurrency = "USD"
    @Published private(set) var rates: [String: Double] = [:]
    @Published private(set) var updatedAt: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var isUsingCachedRates = false
    @Published private(set) var errorMessage: String?

    private let defaults = UserDefaults.standard
    private let session: URLSession
    private let providerName = "open.er-api.com"
    private var activeRequestID: UUID?

    init(session: URLSession = .shared) {
        self.session = session
        restoreCache(for: baseCurrency)
    }

    var convertedValue: Double? {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")),
              amountValue.isFinite,
              amountValue >= 0 else { return nil }
        if baseCurrency == targetCurrency { return amountValue }
        guard let rate = rates[targetCurrency], rate.isFinite else { return nil }
        return amountValue * rate
    }

    var exchangeRate: Double? { baseCurrency == targetCurrency ? 1 : rates[targetCurrency] }

    func loadRates() async {
        let requestID = UUID()
        let requestedBase = baseCurrency
        activeRequestID = requestID
        isLoading = true
        errorMessage = nil
        defer {
            if activeRequestID == requestID { isLoading = false }
        }

        do {
            var components = URLComponents(string: "https://open.er-api.com/v6/latest/\(requestedBase)")
            components?.queryItems = nil
            guard let url = components?.url else { throw CurrencyRateError.invalidResponse }
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw CurrencyRateError.invalidResponse
            }
            let payload = try JSONDecoder().decode(ExchangeRatePayload.self, from: data)
            guard activeRequestID == requestID, baseCurrency == requestedBase else { return }
            guard payload.result == "success", payload.base_code == requestedBase,
                  !payload.rates.isEmpty,
                  payload.rates.values.allSatisfy({ $0.isFinite && $0 > 0 }) else {
                throw CurrencyRateError.providerRejected
            }
            let date = payload.time_last_update_unix.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
            let cache = CachedExchangeRates(baseCode: payload.base_code, rates: payload.rates, updatedAt: date, provider: providerName)
            persist(cache)
            apply(cache, cached: false)
        } catch {
            guard activeRequestID == requestID, baseCurrency == requestedBase else { return }
            restoreCache(for: requestedBase)
            if rates.isEmpty {
                errorMessage = localizedError("لا تتوفر أسعار صرف حاليًا، ولم توجد نسخة محفوظة للعمل دون إنترنت.", "Exchange rates are unavailable and no offline snapshot is saved.")
            } else {
                isUsingCachedRates = true
                errorMessage = localizedError("تعذر التحديث؛ يتم استخدام آخر أسعار محفوظة.", "Update failed; the last saved exchange rates are being used.")
            }
        }
    }

    func changeBaseCurrency(_ code: String) async {
        guard code != baseCurrency else { return }
        baseCurrency = code
        rates = [:]
        updatedAt = nil
        restoreCache(for: code)
        await loadRates()
    }

    func swapCurrencies() {
        let oldBase = baseCurrency
        baseCurrency = targetCurrency
        targetCurrency = oldBase
        // Cross conversion is calculated only from rates downloaded for the selected base.
        Task { await loadRates() }
    }

    private func cacheKey(_ code: String) -> String { "sari.exchange.rates.\(code)" }

    private func persist(_ cache: CachedExchangeRates) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: cacheKey(cache.baseCode))
    }

    private func restoreCache(for code: String) {
        guard let data = defaults.data(forKey: cacheKey(code)),
              let cache = try? JSONDecoder().decode(CachedExchangeRates.self, from: data),
              cache.baseCode == code else { return }
        apply(cache, cached: true)
    }

    private func apply(_ cache: CachedExchangeRates, cached: Bool) {
        rates = cache.rates
        updatedAt = cache.updatedAt
        isUsingCachedRates = cached
    }

    private func localizedError(_ arabic: String, _ english: String) -> String {
        SariTravelFeatureText.text(arabic: arabic, english: english, language: SariLanguage.selected)
    }
}

struct CurrencyOption: Identifiable, Hashable {
    let code: String
    let nameArabic: String
    let nameEnglish: String
    var id: String { code }
    var display: String {
        let language = SariLanguage.selected
        let localeName = Locale(identifier: language.localeIdentifier).localizedString(forCurrencyCode: code)
        let fallback = language.isArabic ? nameArabic : nameEnglish
        return "\(code) — \(localeName ?? fallback)"
    }

    static let all: [CurrencyOption] = [
        .init(code:"SAR",nameArabic:"ريال سعودي",nameEnglish:"Saudi Riyal"),
        .init(code:"USD",nameArabic:"دولار أمريكي",nameEnglish:"US Dollar"),
        .init(code:"EUR",nameArabic:"يورو",nameEnglish:"Euro"),
        .init(code:"GBP",nameArabic:"جنيه إسترليني",nameEnglish:"British Pound"),
        .init(code:"KWD",nameArabic:"دينار كويتي",nameEnglish:"Kuwaiti Dinar"),
        .init(code:"AED",nameArabic:"درهم إماراتي",nameEnglish:"UAE Dirham"),
        .init(code:"QAR",nameArabic:"ريال قطري",nameEnglish:"Qatari Riyal"),
        .init(code:"BHD",nameArabic:"دينار بحريني",nameEnglish:"Bahraini Dinar"),
        .init(code:"OMR",nameArabic:"ريال عماني",nameEnglish:"Omani Rial"),
        .init(code:"JOD",nameArabic:"دينار أردني",nameEnglish:"Jordanian Dinar"),
        .init(code:"EGP",nameArabic:"جنيه مصري",nameEnglish:"Egyptian Pound"),
        .init(code:"TRY",nameArabic:"ليرة تركية",nameEnglish:"Turkish Lira"),
        .init(code:"JPY",nameArabic:"ين ياباني",nameEnglish:"Japanese Yen"),
        .init(code:"CNY",nameArabic:"يوان صيني",nameEnglish:"Chinese Yuan"),
        .init(code:"MYR",nameArabic:"رينغيت ماليزي",nameEnglish:"Malaysian Ringgit"),
        .init(code:"IDR",nameArabic:"روبية إندونيسية",nameEnglish:"Indonesian Rupiah"),
        .init(code:"CHF",nameArabic:"فرنك سويسري",nameEnglish:"Swiss Franc"),
        .init(code:"CAD",nameArabic:"دولار كندي",nameEnglish:"Canadian Dollar"),
        .init(code:"AUD",nameArabic:"دولار أسترالي",nameEnglish:"Australian Dollar"),
        .init(code:"PLN",nameArabic:"زلوتي بولندي",nameEnglish:"Polish Zloty")
    ]
}
