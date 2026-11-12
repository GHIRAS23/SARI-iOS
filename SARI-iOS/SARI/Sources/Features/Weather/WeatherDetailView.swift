import SwiftUI

struct WeatherDetailView: View {
    @EnvironmentObject private var prayer: PrayerStore
    @StateObject private var weather = WeatherStore()
    private var language: SariLanguage { SariLanguage.selected }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color.accentColor.opacity(0.07), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    if let w = weather.snapshot {
                        hero(w)
                        clothing(w)
                        if let alert = w.smartAlert(language) { alertCard(alert) }
                        hourly(w)
                        week(w)
                        details(w)
                    } else if weather.isLoading {
                        ProgressView(SariContentText.pick(language,[.ar:"جاري تحديث توقعات الطقس…",.en:"Updating weather…",.tr:"Hava durumu güncelleniyor…",.ms:"Mengemas kini cuaca…",.id:"Memperbarui cuaca…",.ja:"天気を更新中…",.zh:"正在更新天气…",.ru:"Обновление погоды…",.fr:"Mise à jour de la météo…"]))
                            .padding(.top, 80)
                    } else {
                        ContentUnavailableView(
                            SariContentText.pick(language,[.ar:"تعذر عرض الطقس",.en:"Weather unavailable",.tr:"Hava durumu kullanılamıyor",.ms:"Cuaca tidak tersedia",.id:"Cuaca tidak tersedia",.ja:"天気を表示できません",.zh:"无法显示天气",.ru:"Погода недоступна",.fr:"Météo indisponible"]),
                            systemImage: "cloud.slash",
                            description: Text(weather.errorMessage ?? SariContentText.pick(language,[.ar:"اسمح بالموقع ثم أعد المحاولة.",.en:"Allow location access and try again.",.tr:"Konuma izin verip tekrar deneyin.",.ms:"Benarkan lokasi dan cuba lagi.",.id:"Izinkan lokasi lalu coba lagi.",.ja:"位置情報を許可して再試行してください。",.zh:"请允许定位后重试。",.ru:"Разрешите геолокацию и повторите попытку.",.fr:"Autorisez la localisation puis réessayez."]))
                        )
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle(SariUIStrings.text("weather_clothing", language))
        .navigationBarTitleDisplayMode(.inline)
        .sariLanguageEnvironment(language)
        .task(id: prayer.coordinate.map { "\($0.latitude),\($0.longitude)" }) {
            if prayer.coordinate == nil { prayer.start() }
            guard let c = prayer.coordinate else { return }
            await weather.load(latitude: c.latitude, longitude: c.longitude)
        }
    }

    private func hero(_ w: WeatherSnapshot) -> some View {
        VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 12) {
            HStack {
                Image(systemName: w.symbolName).font(.system(size: 44)).symbolRenderingMode(.multicolor)
                Spacer()
                VStack(alignment: language.isArabic ? .trailing : .leading) {
                    Text(prayer.locationName).font(.headline)
                    Text(w.condition(language)).foregroundStyle(.white.opacity(0.85))
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(w.temperature.rounded()))°").font(.system(size: 64, weight: .black, design: .rounded))
                Text(SariUIStrings.format("feels_value",language,["value":"\(Int(w.apparentTemperature.rounded()))"]))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                if let h = w.high, let l = w.low { Text("↑\(Int(h))°  ↓\(Int(l))°").fontWeight(.semibold) }
            }
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(SariDesign.hero, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(SariDesign.gold.opacity(0.25)))
    }

    private func clothing(_ w: WeatherSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "tshirt.fill").font(.title2).foregroundStyle(SariDesign.emerald)
            VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 6) {
                Text(SariStrings.t("clothes",language)).font(.headline)
                Text(w.clothingAdvice(language)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)
        }
        .padding(20)
        .background(SariDesign.emerald.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func alertCard(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .frame(maxWidth: .infinity, alignment: language.isArabic ? .trailing : .leading)
            .padding(18)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func hourly(_ w: WeatherSnapshot) -> some View {
        VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 12) {
            Text(SariUIStrings.text("next_hours",language)).font(.title3.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(w.hourly.prefix(12)) { h in
                        VStack(spacing: 7) {
                            Text(h.time.formatted(date: .omitted, time: .shortened)).font(.caption)
                            Image(systemName: WeatherSnapshot.symbolName(for: h.weatherCode)).symbolRenderingMode(.multicolor)
                            Text("\(Int(h.temperature))°").font(.headline)
                            Label("\(h.precipitationProbability)%", systemImage: "drop.fill").font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }

    private func week(_ w: WeatherSnapshot) -> some View {
        VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 12) {
            Text(SariUIStrings.text("coming_days",language)).font(.title3.bold())
            VStack(spacing: 0) {
                ForEach(Array(w.daily.enumerated()), id: \.element.id) { index, d in
                    HStack {
                        Text("\(d.precipitationProbability)%").font(.caption).foregroundStyle(.secondary)
                        Image(systemName: WeatherSnapshot.symbolName(for: d.weatherCode)).symbolRenderingMode(.multicolor)
                        Text("↓\(Int(d.low))°  ↑\(Int(d.high))°").fontWeight(.semibold)
                        Spacer()
                        Text(d.date.formatted(.dateTime.weekday(.wide))).fontWeight(.medium)
                    }
                    .padding(.vertical, 12)
                    if index < w.daily.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func details(_ w: WeatherSnapshot) -> some View {
        VStack(spacing: 10) {
            metric(SariUIStrings.text("humidity",language), "\(w.humidity)%", "humidity.fill")
            metric(SariUIStrings.text("wind",language), speed(w.windSpeed), "wind")
            metric(SariContentText.pick(language,[.ar:"الهبات",.en:"Gusts",.tr:"Rüzgâr hamlesi",.ms:"Tiupan",.id:"Hembusan",.ja:"突風",.zh:"阵风",.ru:"Порывы",.fr:"Rafales"]), speed(w.windGust), "wind.circle")
        }
    }

    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(Color.accentColor).frame(width: 28)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.bold())
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func speed(_ value: Double) -> String {
        let unit = SariContentText.pick(language,[.ar:"كم/س",.en:"km/h",.tr:"km/sa",.ms:"km/j",.id:"km/j",.ja:"km/h",.zh:"公里/小时",.ru:"км/ч",.fr:"km/h"])
        return "\(Int(value)) \(unit)"
    }
}
