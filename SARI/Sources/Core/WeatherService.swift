import Foundation

struct WeatherHour: Identifiable, Equatable {
    let id = UUID()
    let time: Date
    let temperature: Double
    let apparentTemperature: Double
    let precipitationProbability: Int
    let weatherCode: Int
    let windSpeed: Double
}

struct WeatherDay: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let weatherCode: Int
    let high: Double
    let low: Double
    let apparentHigh: Double
    let apparentLow: Double
    let precipitationProbability: Int
    let windMax: Double
    let uvIndexMax: Double?
    let sunrise: Date?
    let sunset: Date?
}

struct WeatherSnapshot: Equatable {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double
    let windGust: Double
    let precipitation: Double
    let weatherCode: Int
    let high: Double?
    let low: Double?
    let hourly: [WeatherHour]
    let daily: [WeatherDay]

    var conditionArabic: String { condition(.ar) }

    func condition(_ language: SariLanguage = .selected) -> String {
        SariContentText.weatherCondition(weatherCode, language: language)
    }

    static func conditionArabic(for code: Int) -> String {
        SariContentText.weatherCondition(code, language: .ar)
    }

    static func symbolName(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85...86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }

    var symbolName: String { Self.symbolName(for: weatherCode) }

    var clothingAdviceArabic: String { clothingAdvice(.ar) }

    func clothingAdvice(_ language: SariLanguage = .selected) -> String {
        let rainRisk = daily.first?.precipitationProbability ?? 0
        let rain = precipitation >= 0.2 || rainRisk >= 45 || [51,53,55,56,57,61,63,65,66,67,80,81,82,95,96,99].contains(weatherCode)
        let windy = max(windSpeed, windGust) >= 35
        let swing = daily.first.map { $0.high - $0.low >= 10 } ?? false
        let uvHigh = (daily.first?.uvIndexMax ?? 0) >= 7
        return SariContentText.clothingAdvice(apparent: apparentTemperature, rain: rain, windy: windy, swing: swing, uvHigh: uvHigh, language: language)
    }

    var smartAlertArabic: String? { smartAlert(.ar) }

    func smartAlert(_ language: SariLanguage = .selected) -> String? {
        SariContentText.smartWeatherAlert(
            rain: (daily.first?.precipitationProbability ?? 0) >= 70,
            wind: windGust >= 50,
            uv: (daily.first?.uvIndexMax ?? 0) >= 8,
            heat: (daily.first?.high ?? -100) >= 40,
            language: language
        )
    }

}

@MainActor final class WeatherStore: ObservableObject {
    @Published var snapshot: WeatherSnapshot?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isUsingCachedData = false
    @Published var cachedAt:Date?

    private struct Response: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let apparent_temperature: Double
            let relative_humidity_2m: Int
            let wind_speed_10m: Double
            let wind_gusts_10m: Double?
            let precipitation: Double
            let weather_code: Int
        }
        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double]
            let apparent_temperature: [Double]
            let precipitation_probability: [Int]
            let weather_code: [Int]
            let wind_speed_10m: [Double]
        }
        struct Daily: Decodable {
            let time: [String]
            let weather_code: [Int]
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let apparent_temperature_max: [Double]
            let apparent_temperature_min: [Double]
            let precipitation_probability_max: [Int]
            let wind_speed_10m_max: [Double]
            let uv_index_max: [Double]?
            let sunrise: [String]?
            let sunset: [String]?
        }
        let current: Current
        let hourly: Hourly
        let daily: Daily
    }

    private static let localDateTime: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()

    private static func parseLocal(_ value: String) -> Date? {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current
        f.dateFormat = value.count <= 10 ? "yyyy-MM-dd" : "yyyy-MM-dd'T'HH:mm"
        return f.date(from: value)
    }

    func load(latitude: Double, longitude: Double) async {
        isLoading = true; errorMessage = nil; isUsingCachedData = false
        defer { isLoading = false }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)), .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,wind_gusts_10m,precipitation,weather_code"),
            .init(name: "hourly", value: "temperature_2m,apparent_temperature,precipitation_probability,weather_code,wind_speed_10m"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,precipitation_probability_max,wind_speed_10m_max,uv_index_max,sunrise,sunset"),
            .init(name: "forecast_days", value: "7"), .init(name: "timezone", value: "auto")
        ]
        guard let url = components.url else { errorMessage = SariContentText.pick(SariLanguage.selected,[.ar:"تعذر تكوين طلب الطقس",.en:"Could not prepare the weather request",.tr:"Hava durumu isteği hazırlanamadı",.ms:"Permintaan cuaca tidak dapat disediakan",.id:"Permintaan cuaca tidak dapat disiapkan",.ja:"天気リクエストを準備できませんでした",.zh:"无法准备天气请求",.ru:"Не удалось подготовить запрос погоды",.fr:"Impossible de préparer la requête météo"]); return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { errorMessage = SariContentText.pick(SariLanguage.selected,[.ar:"تعذر تحديث الطقس الآن",.en:"Weather could not be updated right now",.tr:"Hava şu anda güncellenemiyor",.ms:"Cuaca tidak dapat dikemas kini sekarang",.id:"Cuaca tidak dapat diperbarui sekarang",.ja:"現在、天気を更新できません",.zh:"目前无法更新天气",.ru:"Сейчас не удалось обновить погоду",.fr:"Impossible de mettre à jour la météo maintenant"]); return }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            let now = Date().addingTimeInterval(-3600)
            let hours = decoded.hourly.time.indices.compactMap { i -> WeatherHour? in
                guard let time = Self.parseLocal(decoded.hourly.time[i]), time >= now else { return nil }
                return WeatherHour(time: time, temperature: decoded.hourly.temperature_2m[i], apparentTemperature: decoded.hourly.apparent_temperature[i], precipitationProbability: decoded.hourly.precipitation_probability[i], weatherCode: decoded.hourly.weather_code[i], windSpeed: decoded.hourly.wind_speed_10m[i])
            }.prefix(24)
            let days = decoded.daily.time.indices.compactMap { i -> WeatherDay? in
                guard let date = Self.parseLocal(decoded.daily.time[i]) else { return nil }
                return WeatherDay(date: date, weatherCode: decoded.daily.weather_code[i], high: decoded.daily.temperature_2m_max[i], low: decoded.daily.temperature_2m_min[i], apparentHigh: decoded.daily.apparent_temperature_max[i], apparentLow: decoded.daily.apparent_temperature_min[i], precipitationProbability: decoded.daily.precipitation_probability_max[i], windMax: decoded.daily.wind_speed_10m_max[i], uvIndexMax: decoded.daily.uv_index_max?[safe: i], sunrise: decoded.daily.sunrise?[safe: i].flatMap(Self.parseLocal), sunset: decoded.daily.sunset?[safe: i].flatMap(Self.parseLocal))
            }
            snapshot = WeatherSnapshot(temperature: decoded.current.temperature_2m, apparentTemperature: decoded.current.apparent_temperature, humidity: decoded.current.relative_humidity_2m, windSpeed: decoded.current.wind_speed_10m, windGust: decoded.current.wind_gusts_10m ?? decoded.current.wind_speed_10m, precipitation: decoded.current.precipitation, weatherCode: decoded.current.weather_code, high: decoded.daily.temperature_2m_max.first, low: decoded.daily.temperature_2m_min.first, hourly: Array(hours), daily: days) 
            if let snapshot { WeatherCache.save(snapshot) }
            cachedAt=nil

        } catch {
            if let cached=WeatherCache.load() {
                snapshot=cached.0;cachedAt=cached.1;isUsingCachedData=true
                errorMessage=SariContentText.pick(SariLanguage.selected,[.ar:"لا يوجد اتصال — يتم عرض آخر طقس محفوظ.",.en:"Offline — showing the last saved weather.",.tr:"Çevrimdışı — son kaydedilen hava gösteriliyor.",.ms:"Luar talian — memaparkan cuaca terakhir disimpan.",.id:"Offline — menampilkan cuaca terakhir tersimpan.",.ja:"オフライン — 保存済みの最新天気を表示しています。",.zh:"离线 — 正在显示上次保存的天气。",.ru:"Нет сети — показана последняя сохранённая погода.",.fr:"Hors ligne — dernière météo enregistrée affichée."])
            } else { errorMessage=SariContentText.pick(SariLanguage.selected,[.ar:"تعذر تحديث الطقس الآن ولا توجد بيانات محفوظة.",.en:"Weather could not be updated and no saved data is available.",.tr:"Hava güncellenemedi ve kayıtlı veri yok.",.ms:"Cuaca tidak dapat dikemas kini dan tiada data tersimpan.",.id:"Cuaca tidak dapat diperbarui dan tidak ada data tersimpan.",.ja:"天気を更新できず、保存データもありません。",.zh:"无法更新天气，也没有保存的数据。",.ru:"Не удалось обновить погоду, сохранённых данных нет.",.fr:"Impossible de mettre à jour la météo et aucune donnée enregistrée."]) }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
