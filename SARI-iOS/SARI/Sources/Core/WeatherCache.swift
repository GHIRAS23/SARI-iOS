import Foundation

struct CachedWeather:Codable {
    let savedAt:Date
    let temperature:Double,apparentTemperature:Double
    let humidity:Int
    let windSpeed:Double,windGust:Double,precipitation:Double
    let weatherCode:Int
    let high:Double?,low:Double?
}
enum WeatherCache {
    private static var url:URL {
        FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("sari_weather.json")
    }
    static func save(_ s:WeatherSnapshot){
        let c=CachedWeather(savedAt:.now,temperature:s.temperature,apparentTemperature:s.apparentTemperature,humidity:s.humidity,windSpeed:s.windSpeed,windGust:s.windGust,precipitation:s.precipitation,weatherCode:s.weatherCode,high:s.high,low:s.low)
        if let d=try? JSONEncoder().encode(c){try? d.write(to:url,options:.atomic)}
    }
    static func load(maxAge:TimeInterval=6*3600)->(WeatherSnapshot,Date)?{
        guard let d=try? Data(contentsOf:url),let c=try? JSONDecoder().decode(CachedWeather.self,from:d),Date().timeIntervalSince(c.savedAt)<=maxAge else{return nil}
        return (WeatherSnapshot(temperature:c.temperature,apparentTemperature:c.apparentTemperature,humidity:c.humidity,windSpeed:c.windSpeed,windGust:c.windGust,precipitation:c.precipitation,weatherCode:c.weatherCode,high:c.high,low:c.low,hourly:[],daily:[]),c.savedAt)
    }
}
