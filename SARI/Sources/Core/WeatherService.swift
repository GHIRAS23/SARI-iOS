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

    var conditionArabic: String { Self.conditionArabic(for: weatherCode) }

    static func conditionArabic(for code: Int) -> String {
        switch code {
        case 0: return "صحو"
        case 1, 2: return "غائم جزئيًا"
        case 3: return "غائم"
        case 45, 48: return "ضباب"
        case 51, 53, 55, 56, 57: return "رذاذ"
        case 61, 63, 65, 66, 67: return "أمطار"
        case 71, 73, 75, 77: return "ثلوج"
        case 80, 81, 82: return "زخات مطر"
        case 85, 86: return "زخات ثلج"
        case 95, 96, 99: return "عواصف رعدية"
        default: return "طقس متغير"
        }
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

    var clothingAdviceArabic: String {
        var pieces: [String] = []
        switch apparentTemperature {
        case 34...:
            pieces += ["ملابس خفيفة وفضفاضة", "يفضل الألوان الفاتحة"]
        case 27..<34: pieces += ["ملابس صيفية خفيفة"]
        case 20..<27: pieces += ["ملابس خفيفة مع طبقة بسيطة للمساء"]
        case 13..<20: pieces += ["جاكيت خفيف أو كنزة"]
        case 6..<13: pieces += ["جاكيت متوسط وملابس دافئة"]
        default: pieces += ["معطف دافئ وطبقات متعددة"]
        }
        let rainRisk = daily.first?.precipitationProbability ?? 0
        if precipitation >= 0.2 || rainRisk >= 45 || [51,53,55,56,57,61,63,65,66,67,80,81,82,95,96,99].contains(weatherCode) {
            pieces += ["خذ مظلة أو معطفًا مقاومًا للمطر"]
        }
        if max(windSpeed, windGust) >= 35 { pieces += ["الرياح قوية؛ اختر طبقة خارجية ثابتة"] }
        if let today = daily.first, today.high - today.low >= 10 { pieces += ["الحرارة تتغير بوضوح اليوم؛ خذ طبقة إضافية للمساء"] }
        if let uv = daily.first?.uvIndexMax, uv >= 7 { pieces += ["الشمس قوية؛ قبعة وواقي شمس مناسبان للخروج الطويل"] }
        return pieces.joined(separator: "، ") + "."
    }

    var smartAlertArabic: String? {
        if let d = daily.first, d.precipitationProbability >= 70 { return "احتمال المطر مرتفع اليوم؛ خطط للخروج مع مظلة." }
        if windGust >= 50 { return "هبات الرياح قوية؛ انتبه في الأماكن المفتوحة." }
        if let uv = daily.first?.uvIndexMax, uv >= 8 { return "مؤشر الأشعة فوق البنفسجية مرتفع؛ قلل التعرض المباشر وقت الظهيرة." }
        if let d = daily.first, d.high >= 40 { return "حرارة شديدة متوقعة؛ تجنب المجهود الطويل وقت الذروة." }
        return nil
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
        guard let url = components.url else { errorMessage = "تعذر تكوين طلب الطقس"; return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { errorMessage = "تعذر تحديث الطقس الآن"; return }
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
                errorMessage="لا يوجد اتصال — يتم عرض آخر طقس محفوظ."
            } else { errorMessage="تعذر تحديث الطقس الآن ولا توجد بيانات محفوظة." }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
