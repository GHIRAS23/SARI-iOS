import SwiftUI
struct CalendarSettingsView:View {
    @AppStorage("dateDisplayMode",store:UserDefaults(suiteName:"group.sa.sari.app")) private var mode="dual"
    @AppStorage("hijriAdjustment",store:UserDefaults(suiteName:"group.sa.sari.app")) private var adjustment=0
    var body:some View {
        Form {
            Section(SariUIStrings.text("calendar_display",SariLanguage.selected)) {
                Picker(SariUIStrings.text("calendar", SariLanguage.selected),selection:$mode){ForEach(SariDateDisplayMode.allCases){m in Text(m.title).tag(m.rawValue)}}
            }
            Section(SariUIStrings.text("hijri_correction",SariLanguage.selected)) {
                Stepper(SariUIStrings.format("days_value",SariLanguage.selected,["value":"\(adjustment >= 0 ? "+" : "")\(adjustment)"]),value:$adjustment,in:-2...2)
                Button(SariUIStrings.text("reset",SariLanguage.selected)){adjustment=0}.disabled(adjustment==0)
            } footer:{
                Text(SariUIStrings.text("hijri_correction_note",SariLanguage.selected))
            }
            Section(SariUIStrings.text("preview",SariLanguage.selected)) {
                ForEach(SariCalendar.lines(),id:\.self){Text($0)}
            }
        }.navigationTitle(SariUIStrings.text("calendar_date", SariLanguage.selected))
    }
}
