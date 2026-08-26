import SwiftUI

struct PrayerTimesView: View {
    @EnvironmentObject private var prayer: PrayerStore
    var body: some View {
        List {
            if let t = prayer.times {
                Section { row(SariUIStrings.text("fajr", SariLanguage.selected),t.fajr,"sunrise.fill"); row(SariUIStrings.text("sunrise", SariLanguage.selected),t.sunrise,"sun.horizon.fill"); row(SariUIStrings.text("dhuhr", SariLanguage.selected),t.dhuhr,"sun.max.fill"); row(SariUIStrings.text("asr", SariLanguage.selected),t.asr,"sun.min.fill"); row(SariUIStrings.text("maghrib", SariLanguage.selected),t.maghrib,"sunset.fill"); row(SariUIStrings.text("isha", SariLanguage.selected),t.isha,"moon.stars.fill") } header: { Text(SariUIStrings.format("today_prayers_location",SariLanguage.selected,["value":prayer.locationName])) }
                Section { LabeledContent(SariUIStrings.text("prayer_calc_method", SariLanguage.selected),value:prayer.effectiveCalculationMethod.title); NavigationLink { QiblaView() } label: { Label(SariUIStrings.text("qibla_compass",SariLanguage.selected),systemImage:"location.north.circle.fill") }; NavigationLink { PrayerSettingsView() } label: { Label(SariUIStrings.text("adhan_iqama",SariLanguage.selected),systemImage:"bell.badge.fill") } }
            } else { HStack { ProgressView(); Text(SariUIStrings.text("calculating_prayers",SariLanguage.selected)) } }
        }.navigationTitle(SariUIStrings.text("prayer_title",SariLanguage.selected)).environment(\.layoutDirection,SariLanguage.selected.isArabic ? .rightToLeft : .leftToRight).onAppear { prayer.start() }
    }
    private func row(_ name:String,_ date:Date,_ icon:String)->some View { HStack { Label(name,systemImage:icon); Spacer(); Text(date.formatted(date:.omitted,time:.shortened)).fontWeight(.semibold) } }
}
