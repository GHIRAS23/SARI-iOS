import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var prayer: PrayerStore
    @StateObject private var weather = WeatherStore()
    @State private var traveling = false
    @AppStorage("sariLanguage") private var languageRaw=""
    private var language:SariLanguage { SariLanguage(rawValue:languageRaw) ?? .device }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                SariBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        header
                        travelMode
                        prayerHero
                        weatherCard
                        quickActions
                        if traveling { travelCard }
                        prayerStrip
                        safetyFooter
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.layoutDirection, language.isArabic ? .rightToLeft : .leftToRight)
        .onAppear { prayer.start() }
        .task(id: prayer.coordinate.map { "\($0.latitude),\($0.longitude)" }) {
            guard let c = prayer.coordinate else { return }
            await weather.load(latitude: c.latitude, longitude: c.longitude)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(SariUIStrings.text("brand_sari",SariLanguage.selected))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                HStack(spacing: 5) {
                    Image(systemName: "location.fill")
                    Text(prayer.locationName)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            }
            Spacer()
            ZStack {
                Circle().fill(SariDesign.hero).frame(width:58,height:58)
                Circle().stroke(SariDesign.gold.opacity(0.55),lineWidth:1).frame(width:58,height:58)
                Image(systemName:"moon.stars.fill").font(.title2).foregroundStyle(.white)
            }
        }
    }

    private var travelMode: some View {
        HStack(spacing: 8) {
            modeButton(title: SariStrings.t("inCountry",language), icon: "house.fill", selected: !traveling) { withAnimation(.snappy) { traveling = false } }
            modeButton(title: SariStrings.t("traveler",language), icon: "airplane", selected: traveling) { withAnimation(.snappy) { traveling = true } }
        }
        .padding(6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func modeButton(title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) { Image(systemName: icon); Text(title).fontWeight(.bold) }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? SariDesign.emerald : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var prayerHero: some View {
        if let times = prayer.times {
            let next = times.next()
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(alignment: .trailing, spacing: 13) {
                    HStack {
                        Label(SariStrings.t("nextPrayer",language), systemImage: "clock.fill").font(.headline)
                        Spacer()
                        Text(timeRemaining(until: next.1, now: context.date))
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.white.opacity(0.16), in: Capsule())
                    }
                    Text(next.0).font(.system(size: 38, weight: .black, design: .rounded))
                    Text(next.1.formatted(date: .omitted, time: .shortened))
                        .font(.title3.weight(.semibold)).opacity(0.9)
                    HStack(spacing: 14) {
                        Label(SariUIStrings.format("qibla_from_location",SariLanguage.selected,["value":"\(Int(prayer.qiblaBearing))"]), systemImage: "location.north.circle.fill")
                        Spacer()
                        Text(SariUIStrings.text("iqama_customizable", SariLanguage.selected)).font(.caption)
                    }
                    .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(22)
                .background(
                    SariDesign.hero,
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius:28).stroke(SariDesign.gold.opacity(0.34),lineWidth:1))
                .shadow(color:SariDesign.deep.opacity(0.22),radius:22,y:12)
            }
        } else {
            HStack(spacing: 12) { ProgressView(); Text(SariUIStrings.text("locating_prayer", SariLanguage.selected)) }
                .frame(maxWidth: .infinity, alignment: .trailing).padding(20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private var weatherCard: some View {
        NavigationLink(destination: WeatherDetailView()) {
            Group {
                if let w = weather.snapshot {
                    VStack(alignment: .trailing, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .trailing, spacing: 4) { Text(SariStrings.t("weather",language)).font(.headline); Text(w.conditionArabic).foregroundStyle(.secondary) }
                            Spacer(); Image(systemName: w.symbolName).font(.system(size: 34)).symbolRenderingMode(.multicolor)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(w.temperature.rounded()))°").font(.system(size: 44, weight: .black, design: .rounded))
                            Text(SariUIStrings.format("feels_like", SariLanguage.selected, ["value":"\(Int(w.apparentTemperature.rounded()))"])).font(.subheadline).foregroundStyle(.secondary)
                            Spacer(); if let hi = w.high, let lo = w.low { Text("↑\(Int(hi.rounded()))°  ↓\(Int(lo.rounded()))°").font(.subheadline.weight(.semibold)) }
                        }
                        Divider().opacity(0.5)
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "tshirt.fill").font(.title3)
                            VStack(alignment: .trailing, spacing: 4) { Text(SariStrings.t("clothes",language)).font(.subheadline.weight(.bold)); Text(w.clothingAdviceArabic).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                        }
                        HStack { Label(SariUIStrings.format("humidity_value", SariLanguage.selected, ["value":"\(w.humidity)"]), systemImage: "humidity.fill"); Spacer(); Label(SariUIStrings.format("wind_speed", SariLanguage.selected, ["value":"\(Int(w.windSpeed.rounded()))"]), systemImage: "wind") }.font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        HStack { Text(SariUIStrings.text("view_details", SariLanguage.selected)).font(.caption.bold()); Image(systemName: "chevron.left").font(.caption.bold()) }.foregroundStyle(Color.accentColor)
                    }.padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                } else if weather.isLoading { HStack { ProgressView(); Text(SariUIStrings.text("updating_weather", SariLanguage.selected)) }.frame(maxWidth: .infinity).padding(20) }
                else if let message = weather.errorMessage { Label(message, systemImage: "cloud.slash").frame(maxWidth: .infinity, alignment: .trailing).padding(20) }
            }
        }.buttonStyle(.plain)
    }

    private var quickActions: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text(SariUIStrings.text("everything_needed", SariLanguage.selected)).font(.title3.weight(.bold))
            LazyVGrid(columns: columns, spacing: 12) {
                NavigationLink(destination: FiqhAssistantView()) { ActionCard(title: SariStrings.t("ask",language), subtitle: SariStrings.t("fiqhSubtitle",language), icon: "sparkles") }
                NavigationLink(destination: QuranView()) { ActionCard(title: SariStrings.t("quran",language), subtitle: SariStrings.t("quranSubtitle",language), icon: "book.closed.fill") }
                NavigationLink(destination: QiblaView()) { ActionCard(title: SariStrings.t("qibla",language), subtitle: SariUIStrings.format("qibla_from_location",SariLanguage.selected,["value":"\(Int(prayer.qiblaBearing))"]), icon: "location.north.fill") }
                NavigationLink(destination: AdhkarView()) { ActionCard(title: SariStrings.t("adhkar",language), subtitle: SariStrings.t("adhkarSubtitle",language), icon: "hands.sparkles.fill") }
            }
        }
    }

    private var travelCard: some View {
        VStack(alignment: .trailing, spacing: 11) {
            HStack { Text(SariUIStrings.text("travel_enabled", SariLanguage.selected)).font(.headline); Spacer(); Image(systemName: "airplane.circle.fill").font(.title2) }
            Text(SariUIStrings.text("travel_home_desc", SariLanguage.selected))
                .font(.subheadline).foregroundStyle(.secondary)
            Button(SariUIStrings.text("explore_travel", SariLanguage.selected)) { }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder private var prayerStrip: some View {
        if let t = prayer.times {
            VStack(alignment: .trailing, spacing: 12) {
                HStack { NavigationLink(SariUIStrings.text("see_all", SariLanguage.selected)) { PrayerTimesView() }.font(.subheadline.bold()); Spacer(); Text(SariUIStrings.text("today_prayers", SariLanguage.selected)).font(.title3.weight(.bold)) }
                HStack(spacing: 0) {
                    prayerTime(SariUIStrings.text("fajr", SariLanguage.selected), t.fajr)
                    prayerTime(SariUIStrings.text("dhuhr", SariLanguage.selected), t.dhuhr)
                    prayerTime(SariUIStrings.text("asr", SariLanguage.selected), t.asr)
                    prayerTime(SariUIStrings.text("maghrib", SariLanguage.selected), t.maghrib)
                    prayerTime(SariUIStrings.text("isha", SariLanguage.selected), t.isha)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private func prayerTime(_ name: String, _ date: Date) -> some View {
        VStack(spacing: 5) { Text(name).font(.caption.weight(.bold)); Text(date.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity)
    }

    private var safetyFooter: some View {
        Text(SariUIStrings.text("sari_fatwa_note", SariLanguage.selected))
            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 4)
    }

    private func timeRemaining(until date: Date, now: Date) -> String {
        let mins = max(0, Int(date.timeIntervalSince(now) / 60))
        if mins >= 60 { return SariUIStrings.format("hours_minutes_remaining", SariLanguage.selected, ["hours":"\(mins / 60)","minutes":"\(mins % 60)"]) }
        return SariUIStrings.format("minutes_remaining", SariLanguage.selected, ["value":"\(mins)"])
    }
}

private struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius:13).fill(SariDesign.mint.opacity(0.75)).frame(width:44,height:44)
                Image(systemName:icon).font(.system(size:21,weight:.semibold)).foregroundStyle(SariDesign.emerald)
            }.frame(maxWidth:.infinity,alignment:.trailing)
            Spacer(minLength: 4)
            Text(title).font(.headline).foregroundStyle(.primary)
            Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .trailing)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SariBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(.systemBackground), Color.accentColor.opacity(0.06), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}
