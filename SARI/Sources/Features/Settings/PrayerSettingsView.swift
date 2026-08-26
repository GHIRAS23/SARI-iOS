import SwiftUI
import AVFoundation

struct PrayerSettingsView: View {
    @EnvironmentObject private var prayer: PrayerStore
    @AppStorage("iqamaMinutes", store: UserDefaults(suiteName:"group.sa.sari.app")) private var iqama = 15
    @AppStorage("prePrayerMinutes", store: UserDefaults(suiteName:"group.sa.sari.app")) private var prePrayer = 10
    @AppStorage("adhanSound", store: UserDefaults(suiteName:"group.sa.sari.app")) private var selectedSound = "Alimula_29s.caf"
    @State private var player: AVAudioPlayer?
    @AppStorage("calculationMethod",store:UserDefaults(suiteName:"group.sa.sari.app")) private var calcMethod="auto"
    @AppStorage("asrMethod",store:UserDefaults(suiteName:"group.sa.sari.app")) private var asrMethod="standard"
    let sounds=[("Alnufis","Al-Nufais"),("Alimula","Al-Muaiqly"),("Alqitami","Al-Qatami")]
    let prayers=[("fajr",SariUIStrings.text("fajr", SariLanguage.selected)),("dhuhr",SariUIStrings.text("dhuhr", SariLanguage.selected)),("asr",SariUIStrings.text("asr", SariLanguage.selected)),("maghrib",SariUIStrings.text("maghrib", SariLanguage.selected)),("isha",SariUIStrings.text("isha", SariLanguage.selected))]

    var body: some View {
        NavigationStack {
            Form {
                Section(SariUIStrings.text("calculation_method_title", SariLanguage.selected)) {
                    Picker(SariUIStrings.text("calendar_calc", SariLanguage.selected),selection:$calcMethod) {
                        ForEach(PrayerCalculationMethod.allCases){m in Text(m.title).tag(m.rawValue)}
                    }.onChange(of:calcMethod){_,_ in prayer.recalculate()}
                    if calcMethod == "auto" {
                        LabeledContent(SariUIStrings.text("currently_used", SariLanguage.selected),value:prayer.effectiveCalculationMethod.title)
                    }
                    Picker(SariUIStrings.text("asr_calc", SariLanguage.selected),selection:$asrMethod) {
                        ForEach(AsrJuristicMethod.allCases){m in Text(m.title).tag(m.rawValue)}
                    }.onChange(of:asrMethod){_,_ in prayer.recalculate()}
                    NavigationLink(SariUIStrings.text("manual_minutes", SariLanguage.selected)){ PrayerOffsetsView().environmentObject(prayer) }
                    Text(SariUIStrings.text("auto_method_note", SariLanguage.selected)).font(.footnote).foregroundStyle(.secondary)
                }
                Section(SariUIStrings.text("prayer_alerts", SariLanguage.selected)) {
                    ForEach(prayers,id:\.0){ id,name in PrayerToggleRow(id:id,name:name).environmentObject(prayer) }
                }
                Section(SariUIStrings.text("pre_prayer_alert", SariLanguage.selected)) {
                    Toggle(SariUIStrings.text("enable_prealert", SariLanguage.selected),isOn:bindingBool("prePrayerEnabled",defaultValue:true)).onChange(of:bindingBool("prePrayerEnabled",defaultValue:true).wrappedValue){_,_ in prayer.schedulePrayerNotifications()}
                    Stepper(SariUIStrings.format("before_prayer_minutes", SariLanguage.selected, ["value":"\(prePrayer)"]),value:$prePrayer,in:5...30,step:5).onChange(of:prePrayer){_,_ in prayer.schedulePrayerNotifications()}
                }
                Section(SariUIStrings.text("iqama_alert", SariLanguage.selected)) {
                    Toggle(SariUIStrings.text("enable_iqama", SariLanguage.selected),isOn:bindingBool("iqamaEnabled",defaultValue:true)).onChange(of:bindingBool("iqamaEnabled",defaultValue:true).wrappedValue){_,_ in prayer.schedulePrayerNotifications()}
                    Stepper(SariUIStrings.format("after_adhan_minutes", SariLanguage.selected, ["value":"\(iqama)"]),value:$iqama,in:5...60,step:5).onChange(of:iqama){_,_ in prayer.schedulePrayerNotifications()}
                }
                Section(SariUIStrings.text("adhan_sound", SariLanguage.selected)) {
                    ForEach(sounds,id:\.0){file,name in
                        HStack { Button(SariUIStrings.format("preview_name",SariLanguage.selected,["name":name])){ play(file) }; Spacer(); if selectedSound == "\(file)_29s.caf" { Image(systemName:"checkmark.circle.fill").foregroundStyle(.tint) } }
                            .contentShape(Rectangle()).onTapGesture { selectedSound="\(file)_29s.caf"; prayer.schedulePrayerNotifications() }
                    }
                }
                Section { Text(SariUIStrings.text("ios_adhan_note", SariLanguage.selected)).font(.footnote) }
            }.navigationTitle(SariUIStrings.text("prayer_and_adhan", SariLanguage.selected)).environment(\.layoutDirection,SariLanguage.selected.isArabic ? .rightToLeft : .leftToRight)
        }
    }
    private func bindingBool(_ key:String,defaultValue:Bool)->Binding<Bool>{ Binding(get:{ let d=UserDefaults(suiteName:"group.sa.sari.app")!; return d.object(forKey:key)==nil ? defaultValue:d.bool(forKey:key)},set:{UserDefaults(suiteName:"group.sa.sari.app")?.set($0,forKey:key)}) }
    private func play(_ f:String){ guard let u=Bundle.main.url(forResource:f,withExtension:"mp3",subdirectory:"audio") else{return}; player=try? AVAudioPlayer(contentsOf:u); player?.play() }
}
private struct PrayerToggleRow: View {
    @EnvironmentObject var prayer:PrayerStore; let id:String; let name:String
    var body:some View { Toggle(SariUIStrings.format("adhan_name", SariLanguage.selected, ["name":name]),isOn:Binding(get:{let d=UserDefaults(suiteName:"group.sa.sari.app")!; let k="adhan_\(id)"; return d.object(forKey:k)==nil ? true:d.bool(forKey:k)},set:{UserDefaults(suiteName:"group.sa.sari.app")?.set($0,forKey:"adhan_\(id)");prayer.schedulePrayerNotifications()})) }
}

private struct PrayerOffsetsView:View {
    @EnvironmentObject var prayer:PrayerStore
    let rows=[("fajr",SariUIStrings.text("fajr", SariLanguage.selected)),("sunrise",SariUIStrings.text("sunrise", SariLanguage.selected)),("dhuhr",SariUIStrings.text("dhuhr", SariLanguage.selected)),("asr",SariUIStrings.text("asr", SariLanguage.selected)),("maghrib",SariUIStrings.text("maghrib", SariLanguage.selected)),("isha",SariUIStrings.text("isha", SariLanguage.selected))]
    var body:some View {
        Form { ForEach(rows,id:\.0){id,name in OffsetRow(id:id,name:name).environmentObject(prayer) } }
        .navigationTitle(SariUIStrings.text("minute_adjust", SariLanguage.selected))
    }
}
private struct OffsetRow:View {
    @EnvironmentObject var prayer:PrayerStore; let id:String;let name:String
    @State private var value=0
    var body:some View {
        Stepper("\(name): " + SariUIStrings.format("adjustment_minutes",SariLanguage.selected,["value":"\(value >= 0 ? "+" : "")\(value)"]),value:$value,in:-30...30)
            .onAppear{value=UserDefaults(suiteName:"group.sa.sari.app")?.integer(forKey:"offset_\(id)") ?? 0}
            .onChange(of:value){_,v in UserDefaults(suiteName:"group.sa.sari.app")?.set(v,forKey:"offset_\(id)");prayer.recalculate()}
    }
}
