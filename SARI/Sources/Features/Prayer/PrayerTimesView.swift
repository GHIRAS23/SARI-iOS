import SwiftUI

struct PrayerTimesView: View {
    @EnvironmentObject private var prayer: PrayerStore
    var body: some View {
        List {
            if let t = prayer.times {
                Section { row(SariContentText.prayerName("fajr",language:SariLanguage.selected),t.fajr,"sunrise.fill"); row(SariContentText.prayerName("sunrise",language:SariLanguage.selected),t.sunrise,"sun.horizon.fill"); row(SariContentText.prayerName("dhuhr",language:SariLanguage.selected),t.dhuhr,"sun.max.fill"); row(SariContentText.prayerName("asr",language:SariLanguage.selected),t.asr,"sun.min.fill"); row(SariContentText.prayerName("maghrib",language:SariLanguage.selected),t.maghrib,"sunset.fill"); row(SariContentText.prayerName("isha",language:SariLanguage.selected),t.isha,"moon.stars.fill") } header: { Text(SariUIStrings.format("today_prayers_location",SariLanguage.selected,["value":prayer.locationName])) }
                Section { LabeledContent(SariUIStrings.text("prayer_calc_method", SariLanguage.selected),value:prayer.effectiveCalculationMethod.title(SariLanguage.selected)); NavigationLink { QiblaView() } label: { Label(SariUIStrings.text("qibla_compass",SariLanguage.selected),systemImage:"location.north.circle.fill") }; NavigationLink { PrayerSettingsView() } label: { Label(SariUIStrings.text("adhan_iqama",SariLanguage.selected),systemImage:"bell.badge.fill") } }
            } else { HStack { ProgressView(); Text(SariUIStrings.text("calculating_prayers",SariLanguage.selected)) } }
        }.navigationTitle(SariUIStrings.text("prayer_title",SariLanguage.selected)).environment(\.layoutDirection,SariLanguage.selected.isArabic ? .rightToLeft : .leftToRight).onAppear { prayer.start() }
    }
    private func row(_ name:String,_ date:Date,_ icon:String)->some View { HStack { Label(name,systemImage:icon); Spacer(); Text(date.formatted(date:.omitted,time:.shortened)).fontWeight(.semibold) } }
}
