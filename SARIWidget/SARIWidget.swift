import WidgetKit
import SwiftUI

struct PrayerEntry: TimelineEntry {
    let date: Date
    let prayer: String
    let prayerTime: Date
    let location: String
    let updated: Date
    let qibla: Double
}

struct Provider: TimelineProvider {
    private let suite = UserDefaults(suiteName: "group.sa.sari.app")

    func entry() -> PrayerEntry {
        let storedPrayer = suite?.string(forKey: "nextPrayer")
        let storedPrayerTime = suite?.double(forKey: "nextPrayerTime") ?? 0
        let storedUpdatedAt = suite?.double(forKey: "updatedAt") ?? 0

        return PrayerEntry(
            date: .now,
            prayer: storedPrayer?.isEmpty == false ? storedPrayer! : "Next Prayer",
            prayerTime: storedPrayerTime > 0
                ? Date(timeIntervalSince1970: storedPrayerTime)
                : .now,
            location: suite?.string(forKey: "location") ?? "SARI",
            updated: storedUpdatedAt > 0
                ? Date(timeIntervalSince1970: storedUpdatedAt)
                : .now,
            qibla: suite?.double(forKey: "qiblaBearing") ?? 0
        )
    }

    func placeholder(in context: Context) -> PrayerEntry {
        entry()
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (PrayerEntry) -> Void
    ) {
        completion(entry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<PrayerEntry>) -> Void
    ) {
        let currentEntry = entry()

        let refreshDate = max(
            Date().addingTimeInterval(300),
            min(
                currentEntry.prayerTime.addingTimeInterval(60),
                Date().addingTimeInterval(1800)
            )
        )

        completion(
            Timeline(
                entries: [currentEntry],
                policy: .after(refreshDate)
            )
        )
    }
}

struct SARIWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SARI")
                    .font(.headline)

                Spacer()

                Text(entry.location)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(entry.prayer)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(entry.prayerTime, style: .time)
                .font(.title3)
                .monospacedDigit()

            if family == .systemMedium {
                HStack {
                    Label(
                        "\(Int(entry.qibla.rounded()))°",
                        systemImage: "location.north.line"
                    )

                    Spacer()

                    Text(entry.prayerTime, style: .relative)
                        .monospacedDigit()
                }
                .font(.caption)
            }

            Spacer(minLength: 0)

            Text(
                entry.updated.formatted(
                    date: .omitted,
                    time: .shortened
                )
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct SARIWidget: Widget {
    let kind = "SARI.PrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: Provider()
        ) { entry in
            SARIWidgetView(entry: entry)
        }
        .configurationDisplayName("SARI")
        .description("Prayer times and Qibla")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}