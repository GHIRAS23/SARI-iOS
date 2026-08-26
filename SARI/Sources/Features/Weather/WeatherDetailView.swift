import SwiftUI

struct WeatherDetailView: View {
    @EnvironmentObject private var prayer: PrayerStore
    @StateObject private var weather = WeatherStore()
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(.systemBackground), Color.accentColor.opacity(0.07), Color(.systemBackground)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView(showsIndicators: false) { VStack(spacing: 18) {
                if let w = weather.snapshot { hero(w); clothing(w); if let a = w.smartAlertArabic { alertCard(a) }; hourly(w); week(w); details(w) }
                else if weather.isLoading { ProgressView("جاري تحديث توقعات الطقس…").padding(.top, 80) }
                else { ContentUnavailableView("تعذر عرض الطقس", systemImage: "cloud.slash", description: Text(weather.errorMessage ?? "اسمح بالموقع ثم أعد المحاولة.")) }
            }.padding(18) }
        }
        .navigationTitle(SariUIStrings.text("weather_clothing",SariLanguage.selected)).navigationBarTitleDisplayMode(.inline).environment(\.layoutDirection,SariLanguage.selected.isArabic ? .rightToLeft : .leftToRight)
        .task(id: prayer.coordinate.map { "\($0.latitude),\($0.longitude)" }) { if prayer.coordinate == nil { prayer.start() }; guard let c = prayer.coordinate else { return }; await weather.load(latitude: c.latitude, longitude: c.longitude) }
    }
    private func hero(_ w: WeatherSnapshot) -> some View { VStack(alignment: .trailing, spacing: 12) {
        HStack { Image(systemName: w.symbolName).font(.system(size: 44)); Spacer(); VStack(alignment: .trailing) { Text(prayer.locationName).font(.headline); Text(w.conditionArabic).foregroundStyle(.secondary) } }
        HStack(alignment: .firstTextBaseline) { Text("\(Int(w.temperature.rounded()))°").font(.system(size: 64, weight: .black, design: .rounded)); Text(SariUIStrings.format("feels_value",SariLanguage.selected,["value":"\(Int(w.apparentTemperature.rounded()))"])).foregroundStyle(.secondary); Spacer(); if let h = w.high, let l = w.low { Text("↑\(Int(h))°  ↓\(Int(l))°").fontWeight(.semibold) } }
    }.foregroundStyle(.white).padding(22).background(SariDesign.hero, in: RoundedRectangle(cornerRadius: 28)).overlay(RoundedRectangle(cornerRadius:28).stroke(SariDesign.gold.opacity(0.25))) }
    private func clothing(_ w: WeatherSnapshot) -> some View { HStack(alignment: .top, spacing: 12) { Image(systemName: "tshirt.fill").font(.title2); VStack(alignment: .trailing, spacing: 6) { Text(SariStrings.t("clothes")).font(.headline); Text(w.clothingAdviceArabic).foregroundStyle(.secondary) } }.frame(maxWidth: .infinity, alignment: .trailing).padding(20).background(SariDesign.emerald.opacity(0.10), in: RoundedRectangle(cornerRadius: 24)) }
    private func alertCard(_ text: String) -> some View { Label(text, systemImage: "exclamationmark.triangle.fill").frame(maxWidth: .infinity, alignment: .trailing).padding(18).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 20)) }
    private func hourly(_ w: WeatherSnapshot) -> some View { VStack(alignment: .trailing, spacing: 12) { Text(SariUIStrings.text("next_hours",SariLanguage.selected)).font(.title3.bold()); ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) { ForEach(w.hourly.prefix(12)) { h in VStack(spacing: 7) { Text(h.time.formatted(date: .omitted, time: .shortened)).font(.caption); Image(systemName: WeatherSnapshot.symbolName(for: h.weatherCode)); Text("\(Int(h.temperature))°").font(.headline); Label("\(h.precipitationProbability)%", systemImage: "drop.fill").font(.caption2).foregroundStyle(.secondary) }.padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18)) } } } } }
    private func week(_ w: WeatherSnapshot) -> some View { VStack(alignment: .trailing, spacing: 12) { Text(SariUIStrings.text("coming_days", SariLanguage.selected)).font(.title3.bold()); VStack(spacing: 0) { ForEach(Array(w.daily.enumerated()), id: \.element.id) { index, d in HStack { Text("\(d.precipitationProbability)%").font(.caption).foregroundStyle(.secondary); Image(systemName: WeatherSnapshot.symbolName(for: d.weatherCode)); Text("↓\(Int(d.low))°  ↑\(Int(d.high))°").fontWeight(.semibold); Spacer(); Text(d.date.formatted(.dateTime.weekday(.wide))).fontWeight(.medium) }.padding(.vertical, 12); if index < w.daily.count - 1 { Divider() } } }.padding(.horizontal, 16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22)) } }
    private func details(_ w: WeatherSnapshot) -> some View { HStack(spacing: 10) { metric(SariUIStrings.text("humidity", SariLanguage.selected), "\(w.humidity)%", "humidity.fill"); metric(SariUIStrings.text("wind", SariLanguage.selected), "\(Int(w.windSpeed)) كم/س", "wind"); metric("الهبات", "\(Int(w.windGust)) كم/س", "wind.circle") } }
    private func metric(_ title: String, _ value: String, _ icon: String) -> some View { VStack(spacing: 6) { Image(systemName: icon); Text(value).font(.subheadline.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(14).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18)) }
}
