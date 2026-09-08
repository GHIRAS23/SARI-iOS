import SwiftUI

struct PrayerTimesView: View {
    @EnvironmentObject private var prayer: PrayerStore
    @AppStorage("sariLanguage") private var languageRaw = ""

    private var language: SariLanguage {
        SariLanguage(rawValue: languageRaw) ?? .device
    }

    var body: some View {
        List {
            if let message = prayer.locationMessage, !message.isEmpty {
                Section {
                    Label(message, systemImage: prayer.locationDenied ? "location.slash" : "location")
                        .font(.footnote)
                        .foregroundStyle(prayer.locationDenied ? .orange : .secondary)
                }
            }

            if let times = prayer.times {
                Section {
                    row("fajr", times.fajr, "sunrise.fill")
                    row("sunrise", times.sunrise, "sun.horizon.fill")
                    row("dhuhr", times.dhuhr, "sun.max.fill")
                    row("asr", times.asr, "sun.min.fill")
                    row("maghrib", times.maghrib, "sunset.fill")
                    row("isha", times.isha, "moon.stars.fill")
                } header: {
                    Text(
                        SariUIStrings.format(
                            "today_prayers_location",
                            language,
                            ["value": prayer.locationName]
                        )
                    )
                } footer: {
                    VStack(alignment: language.isRTL ? .trailing : .leading, spacing: 4) {
                        Text(timeZoneLabel)
                        if let calculated = prayer.lastCalculationDate {
                            Text(lastUpdatedLabel(calculated))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: language.isRTL ? .trailing : .leading)
                }

                Section {
                    LabeledContent(
                        SariUIStrings.text("prayer_calc_method", language),
                        value: prayer.effectiveCalculationMethod.title(language)
                    )
                    NavigationLink { QiblaView() } label: {
                        Label(SariUIStrings.text("qibla_compass", language), systemImage: "location.north.circle.fill")
                    }
                    NavigationLink { PrayerSettingsView() } label: {
                        Label(SariUIStrings.text("adhan_iqama", language), systemImage: "bell.badge.fill")
                    }
                }
            } else {
                HStack {
                    ProgressView()
                    Text(SariUIStrings.text("calculating_prayers", language))
                }
            }
        }
        .navigationTitle(SariUIStrings.text("prayer_title", language))
        .sariLanguageEnvironment(language)
        .onAppear { prayer.start() }
        .refreshable {
            prayer.start()
            prayer.refreshForToday(force: true)
        }
    }

    private func row(_ id: String, _ date: Date, _ icon: String) -> some View {
        HStack {
            Label(SariContentText.prayerName(id, language: language), systemImage: icon)
            Spacer()
            Text(formattedPrayerTime(date))
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }

    private func formattedPrayerTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.timeZone = prayer.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private var timeZoneLabel: String {
        SariContentText.pick(language, [
            .ar: "المنطقة الزمنية: \(prayer.timeZone.identifier)",
            .en: "Time zone: \(prayer.timeZone.identifier)",
            .tr: "Saat dilimi: \(prayer.timeZone.identifier)",
            .ms: "Zon waktu: \(prayer.timeZone.identifier)",
            .id: "Zona waktu: \(prayer.timeZone.identifier)",
            .ja: "タイムゾーン: \(prayer.timeZone.identifier)",
            .zh: "时区：\(prayer.timeZone.identifier)",
            .ru: "Часовой пояс: \(prayer.timeZone.identifier)",
            .fr: "Fuseau horaire : \(prayer.timeZone.identifier)"
        ])
    }

    private func lastUpdatedLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.timeZone = prayer.timeZone
        formatter.timeStyle = .short
        let value = formatter.string(from: date)
        return SariContentText.pick(language, [
            .ar: "آخر حساب: \(value)", .en: "Last calculated: \(value)", .tr: "Son hesaplama: \(value)",
            .ms: "Kiraan terakhir: \(value)", .id: "Perhitungan terakhir: \(value)", .ja: "最終計算: \(value)",
            .zh: "最后计算：\(value)", .ru: "Последний расчёт: \(value)", .fr: "Dernier calcul : \(value)"
        ])
    }
}
