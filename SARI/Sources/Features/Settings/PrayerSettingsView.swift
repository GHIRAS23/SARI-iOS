import SwiftUI
import AVFoundation

private struct AdhanSoundOption: Identifiable {
    let id: String
    let arabicName: String
    let englishName: String
    var previewFile: String { id }
    var notificationFile: String { "\(id).caf" }
    func name(_ language: SariLanguage) -> String { language.isArabic ? arabicName : englishName }
}

struct PrayerSettingsView: View {
    @EnvironmentObject private var prayer: PrayerStore
    @AppStorage("prePrayerMinutes", store: UserDefaults(suiteName:"group.sa.sari.app")) private var prePrayer = 10
    @AppStorage("adhanSound", store: UserDefaults(suiteName:"group.sa.sari.app")) private var selectedSound = "AdhanAliMulla.caf"
    @AppStorage("calculationMethod",store:UserDefaults(suiteName:"group.sa.sari.app")) private var calcMethod="auto"
    @AppStorage("asrMethod",store:UserDefaults(suiteName:"group.sa.sari.app")) private var asrMethod="standard"
    @State private var player: AVAudioPlayer?
    @State private var audioError: String?
    private var language: SariLanguage { SariLanguage.selected }

    private let sounds: [AdhanSoundOption] = [
        .init(id:"AdhanDughariri", arabicName:"الدغريري", englishName:"Al-Dughariri"),
        .init(id:"AdhanQatami", arabicName:"القطامي", englishName:"Al-Qatami"),
        .init(id:"AdhanBaafif", arabicName:"عبدالله باعفيف", englishName:"Abdullah Baafif"),
        .init(id:"AdhanAliMulla", arabicName:"علي ملا", englishName:"Ali Mulla")
    ]

    private var prayers: [(String,String)] {
        ["fajr","dhuhr","asr","maghrib","isha"].map { ($0,SariContentText.prayerName($0, language: language)) }
    }

    var body: some View {
        Form {
            Section(SariUIStrings.text("calculation_method_title", language)) {
                Picker(SariUIStrings.text("calendar_calc", language),selection:$calcMethod) {
                    ForEach(PrayerCalculationMethod.allCases){m in Text(m.title(language)).tag(m.rawValue)}
                }.onChange(of:calcMethod){_,_ in prayer.recalculate()}
                if calcMethod == "auto" {
                    LabeledContent(SariUIStrings.text("currently_used", language),value:prayer.effectiveCalculationMethod.title(language))
                }
                Picker(SariUIStrings.text("asr_calc", language),selection:$asrMethod) {
                    ForEach(AsrJuristicMethod.allCases){m in Text(m.title(language)).tag(m.rawValue)}
                }.onChange(of:asrMethod){_,_ in prayer.recalculate()}
                NavigationLink(SariUIStrings.text("manual_minutes", language)){ PrayerOffsetsView().environmentObject(prayer) }
                Text(SariUIStrings.text("auto_method_note", language)).font(.footnote).foregroundStyle(.secondary)
            }

            Section(SariUIStrings.text("prayer_alerts", language)) {
                ForEach(prayers,id:\.0){ id,name in PrayerToggleRow(id:id,name:name).environmentObject(prayer) }
            }

            Section(SariUIStrings.text("pre_prayer_alert", language)) {
                Toggle(SariUIStrings.text("enable_prealert", language),isOn:bindingBool("prePrayerEnabled",defaultValue:true))
                    .onChange(of:bindingBool("prePrayerEnabled",defaultValue:true).wrappedValue){_,_ in prayer.schedulePrayerNotifications()}
                Stepper(SariUIStrings.format("before_prayer_minutes", language, ["value":"\(prePrayer)"]),value:$prePrayer,in:5...30,step:5)
                    .onChange(of:prePrayer){_,_ in prayer.schedulePrayerNotifications()}
            }

            Section {
                Toggle(iqamaToggleTitle,isOn:bindingBool("iqamaEnabled",defaultValue:true))
                    .onChange(of:bindingBool("iqamaEnabled",defaultValue:true).wrappedValue){_,_ in prayer.schedulePrayerNotifications()}
                if bindingBool("iqamaEnabled",defaultValue:true).wrappedValue {
                    ForEach(prayers,id:\.0) { id,name in
                        IqamaMinutesRow(id:id,name:name).environmentObject(prayer)
                    }
                }
            } header: {
                Text(iqamaSectionTitle)
            } footer: {
                Text(iqamaFooter).font(.footnote)
            }

            Section {
                ForEach(sounds) { sound in
                    HStack(spacing: 12) {
                        Button {
                            select(sound)
                        } label: {
                            Image(systemName: selectedSound == sound.notificationFile ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedSound == sound.notificationFile ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: language.isArabic ? .trailing : .leading, spacing: 3) {
                            Text(sound.name(language)).font(.headline)
                            Text(SariContentText.pick(language,[.ar:"صوت أذان قصير مناسب لإشعارات iOS",.en:"iOS-ready short Adhan sound",.tr:"iOS bildirimine uygun kısa ezan",.ms:"Azan ringkas sesuai untuk notifikasi iOS",.id:"Azan singkat untuk notifikasi iOS",.ja:"iOS通知対応の短いアザーン",.zh:"适用于 iOS 通知的短版宣礼",.ru:"Короткий азан для уведомлений iOS",.fr:"Adhan court adapté aux notifications iOS"]))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth:.infinity,alignment: language.isArabic ? .trailing : .leading)

                        Button { play(sound) } label: {
                            Image(systemName:"play.circle.fill").font(.title2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(SariUIStrings.format("preview_name",language,["name":sound.name(language)]))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { select(sound) }
                }
                if let audioError { Text(audioError).font(.caption).foregroundStyle(.red) }
            } header: {
                Text(SariUIStrings.text("adhan_sound", language))
            } footer: {
                Text(SariUIStrings.text("ios_adhan_note", language)).font(.footnote)
            }
        }
        .navigationTitle(SariUIStrings.text("prayer_and_adhan", language))
        .sariLanguageEnvironment(language)
        .onAppear {
            let valid = Set(sounds.map(\.notificationFile))
            if !valid.contains(selectedSound) {
                selectedSound = "AdhanAliMulla.caf"
                prayer.schedulePrayerNotifications()
            }
        }
        .onDisappear { player?.stop() }
    }

    private var iqamaSectionTitle:String { SariContentText.pick(language,[.ar:"عداد الإقامة",.en:"Iqama countdown",.tr:"Kamet sayacı",.ms:"Kiraan Iqamah",.id:"Hitung mundur Iqamah",.ja:"イカーマのカウントダウン",.zh:"成拜倒计时",.ru:"Отсчёт до икамата",.fr:"Compte à rebours Iqama"]) }
    private var iqamaToggleTitle:String { SariContentText.pick(language,[.ar:"إظهار وتنبيه وقت الإقامة",.en:"Show and notify Iqama time",.tr:"Kamet zamanını göster ve bildir",.ms:"Papar dan maklumkan waktu Iqamah",.id:"Tampilkan dan beri notifikasi Iqamah",.ja:"イカーマ時刻を表示・通知",.zh:"显示并提醒成拜时间",.ru:"Показывать и уведомлять об икамате",.fr:"Afficher et notifier l’Iqama"]) }
    private var iqamaFooter:String { SariContentText.pick(language,[.ar:"حدد المدة بعد الأذان لكل صلاة. بعد الإقامة تتحول الواجهة تلقائيًا إلى الصلاة القادمة.",.en:"Set the delay after Adhan for each prayer. After Iqama, SARI automatically shows the next prayer.",.tr:"Her namaz için ezandan sonraki süreyi belirleyin. Kametten sonra sonraki namaz gösterilir.",.ms:"Tetapkan sela selepas azan bagi setiap solat. Selepas Iqamah, SARI menunjukkan solat seterusnya.",.id:"Atur jeda setelah azan untuk tiap salat. Setelah Iqamah, SARI menampilkan salat berikutnya.",.ja:"各礼拝のアザーン後の時間を設定します。イカーマ後は次の礼拝に切り替わります。",.zh:"可为每次礼拜设置宣礼后的成拜间隔。成拜后自动显示下一次礼拜。",.ru:"Задайте интервал после азана для каждой молитвы. После икамата показывается следующая молитва.",.fr:"Réglez le délai après l’Adhan pour chaque prière. Après l’Iqama, SARI affiche la prière suivante."]) }

    private func bindingBool(_ key:String,defaultValue:Bool)->Binding<Bool>{
        Binding(get:{ let d=UserDefaults(suiteName:"group.sa.sari.app")!; return d.object(forKey:key)==nil ? defaultValue:d.bool(forKey:key)},set:{UserDefaults(suiteName:"group.sa.sari.app")?.set($0,forKey:key)})
    }

    private func select(_ sound: AdhanSoundOption) {
        selectedSound = sound.notificationFile
        prayer.schedulePrayerNotifications()
    }

    private func play(_ sound: AdhanSoundOption) {
        audioError=nil
        guard let url=Bundle.main.sariResourceURL(name:sound.previewFile,extension:"m4a",subdirectory:"audio") else {
            audioError = SariContentText.pick(language,[.ar:"تعذر العثور على ملف المعاينة.",.en:"Preview audio file was not found."])
            return
        }
        do {
            let session=AVAudioSession.sharedInstance()
            try session.setCategory(.playback,mode:.default,options:[.duckOthers])
            try session.setActive(true)
            player=try AVAudioPlayer(contentsOf:url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            audioError=SariContentText.pick(language,[.ar:"تعذر تشغيل معاينة الأذان.",.en:"Adhan preview could not be played."])
        }
    }
}

private struct IqamaMinutesRow: View {
    @EnvironmentObject var prayer: PrayerStore
    let id:String
    let name:String
    @State private var minutes=15
    private var language:SariLanguage { SariLanguage.selected }

    var body: some View {
        Stepper(value:$minutes,in:5...60,step:5) {
            HStack {
                Text(name)
                Spacer()
                Text(SariContentText.pick(language,[.ar:"بعد \(minutes) دقيقة",.en:"+\(minutes) min",.tr:"+\(minutes) dk",.ms:"+\(minutes) min",.id:"+\(minutes) mnt",.ja:"+\(minutes)分",.zh:"+\(minutes) 分钟",.ru:"+\(minutes) мин",.fr:"+\(minutes) min"]))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            let d=UserDefaults(suiteName:"group.sa.sari.app")
            let saved=d?.integer(forKey:"iqama_\(id)") ?? 0
            minutes=saved > 0 ? saved : 15
        }
        .onChange(of:minutes){_,v in
            UserDefaults(suiteName:"group.sa.sari.app")?.set(v,forKey:"iqama_\(id)")
            prayer.schedulePrayerNotifications()
        }
    }
}

private struct PrayerToggleRow: View {
    @EnvironmentObject var prayer:PrayerStore; let id:String; let name:String
    var body:some View {
        Toggle(SariUIStrings.format("adhan_name", SariLanguage.selected, ["name":name]),isOn:Binding(get:{let d=UserDefaults(suiteName:"group.sa.sari.app")!; let k="adhan_\(id)"; return d.object(forKey:k)==nil ? true:d.bool(forKey:k)},set:{UserDefaults(suiteName:"group.sa.sari.app")?.set($0,forKey:"adhan_\(id)");prayer.schedulePrayerNotifications()}))
    }
}

private struct PrayerOffsetsView:View {
    @EnvironmentObject var prayer:PrayerStore
    var rows:[(String,String)] { ["fajr","sunrise","dhuhr","asr","maghrib","isha"].map{($0,SariContentText.prayerName($0,language:SariLanguage.selected))} }
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
