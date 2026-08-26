import WidgetKit
import SwiftUI

struct PrayerEntry:TimelineEntry {
    let date:Date; let prayer:String; let prayerTime:Date; let location:String; let updated:Date; let qibla:Double
}
struct Provider:TimelineProvider {
    let suite=UserDefaults(suiteName:"group.sa.sari.app")
    func entry()->PrayerEntry {
        .init(date:.now,
              prayer:suite?.string(forKey:"nextPrayer") ?? SariUIStrings.text("next_prayer", SariLanguage.selected),
              prayerTime:Date(timeIntervalSince1970:suite?.double(forKey:"nextPrayerTime") ?? Date().timeIntervalSince1970),
              location:suite?.string(forKey:"location") ?? "SARI",
              updated:Date(timeIntervalSince1970:suite?.double(forKey:"updatedAt") ?? 0),
              qibla:suite?.double(forKey:"qiblaBearing") ?? 0)
    }
    func placeholder(in context:Context)->PrayerEntry{entry()}
    func getSnapshot(in context:Context,completion:@escaping(PrayerEntry)->Void){completion(entry())}
    func getTimeline(in context:Context,completion:@escaping(Timeline<PrayerEntry>)->Void){
        let e=entry()
        let refresh=max(Date().addingTimeInterval(300), min(e.prayerTime.addingTimeInterval(60), Date().addingTimeInterval(1800)))
        completion(Timeline(entries:[e],policy:.after(refresh)))
    }
}
struct SARIWidgetView:View {
    @Environment(\.widgetFamily) var family
    let entry:PrayerEntry
    var body:some View {
        VStack(alignment:.leading,spacing:6){
            HStack { Text("SARI").font(.headline); Spacer(); Text(entry.location).font(.caption2).foregroundStyle(.secondary) }
            Text(entry.prayer).font(.title2.bold())
            Text(entry.prayerTime,style:.time).font(.title3)
            if family == .systemMedium {
                HStack { Label("\(Int(entry.qibla))°", systemImage:"location.north.line"); Spacer(); Text(entry.prayerTime,style:.relative).monospacedDigit() }.font(.caption)
            }
            Text(entry.updated.formatted(date:.omitted,time:.shortened)).font(.caption2).foregroundStyle(.secondary)
        }.containerBackground(.fill.tertiary,for:.widget)
    }
}
@main struct SARIWidget:Widget {
    var body:some WidgetConfiguration {
        StaticConfiguration(kind:"SARI.PrayerWidget",provider:Provider()){SARIWidgetView(entry:$0)}
            .configurationDisplayName(SariUIStrings.text("next_prayer", SariLanguage.selected))
            .description("SARI")
            .supportedFamilies([.systemSmall,.systemMedium])
    }
}
