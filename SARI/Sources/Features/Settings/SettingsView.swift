import SwiftUI

struct SettingsView:View {
    @AppStorage("sariLanguage") private var languageRaw=""
    @AppStorage("sariAppearance") private var appearanceRaw="system"
    @StateObject private var pack=LocalFiqhPack.shared
    @State private var showDelete=false
    private var language:SariLanguage { SariLanguage(rawValue:languageRaw) ?? SariLanguage.device }
    var body:some View {
        NavigationStack {
            List {
                Section {
                    Picker(SariUIStrings.text("app_language", language),selection:$languageRaw) {
                        Text(SariUIStrings.format("automatic_device",language,["value":SariLanguage.device.displayName])).tag("")
                        ForEach(SariLanguage.allCases){l in Text(l.displayName).tag(l.rawValue)}
                    }
                } header:{Text(SariUIStrings.text("language", language))}
                  footer:{Text(SariUIStrings.text("settings_language_note", language))}

                Section(SariUIStrings.text("date",language)) {
                    NavigationLink { CalendarSettingsView() } label:{Label(SariUIStrings.text("calendar_date",language),systemImage:"calendar")}
                }

                Section(SariUIStrings.text("appearance",language)) {
                    Picker(SariUIStrings.text("theme",language),selection:$appearanceRaw) {
                        ForEach(SariAppearance.allCases){a in Text(a.title(language)).tag(a.rawValue)}
                    }
                }

                Section(SariUIStrings.text("worship", language)) {
                    NavigationLink { PrayerSettingsView() } label:{Label(SariUIStrings.text("prayer_adhan_iqama",language),systemImage:"bell.badge.fill")}
                    NavigationLink { AdhkarView() } label:{Label(SariUIStrings.text("adhkar", language),systemImage:"heart.fill")}
                }

                Section(SariUIStrings.text("local_fiqh", language)) {
                    if pack.installed {
                        Label(
                            SariContentText.pick(language,[
                                .ar:"المصادر الفقهية الأساسية جاهزة",.en:"Core fiqh sources are ready",.tr:"Temel fıkıh kaynakları hazır",.ms:"Sumber fiqh asas sedia",.id:"Sumber fikih inti siap",.ja:"基本フィクフ資料は準備済み",.zh:"基础教法来源已就绪",.ru:"Основные источники фикха готовы",.fr:"Les sources principales de fiqh sont prêtes"
                            ]),
                            systemImage:"checkmark.seal.fill"
                        ).foregroundStyle(.green)
                        NavigationLink { FiqhPackSetupView() } label:{
                            Label(SariContentText.pick(language,[.ar:"إعدادات المساعد المحلي",.en:"Local assistant settings",.tr:"Yerel asistan ayarları",.ms:"Tetapan pembantu tempatan",.id:"Pengaturan asisten lokal",.ja:"ローカル助手の設定",.zh:"本地助手设置",.ru:"Настройки локального помощника",.fr:"Réglages de l’assistant local"]),systemImage:"brain.head.profile")
                        }
                        if pack.hasModel || pack.installedVersion != nil {
                            Button(role:.destructive){showDelete=true}label:{Label(SariUIStrings.text("delete_assistant_pack",language),systemImage:"trash")}
                        }
                    } else {
                        NavigationLink { FiqhPackSetupView() } label:{Label(SariContentText.pick(language,[.ar:"تجهيز مصادر المساعد",.en:"Prepare assistant sources",.tr:"Asistan kaynaklarını hazırla",.ms:"Sediakan sumber pembantu",.id:"Siapkan sumber asisten",.ja:"助手資料を準備",.zh:"准备助手来源",.ru:"Подготовить источники помощника",.fr:"Préparer les sources de l’assistant"]),systemImage:"arrow.clockwise")}
                    }
                }
            }
            .navigationTitle(SariStrings.t("settings",language))
            .tint(SariDesign.emerald)
            .scrollContentBackground(.hidden)
            .background(LinearGradient(colors:[SariDesign.mint.opacity(0.35),Color(.systemBackground)],startPoint:.top,endPoint:.bottom))
            .confirmationDialog(SariUIStrings.text("delete_assistant_files",language),isPresented:$showDelete,titleVisibility:.visible) {
                Button(SariUIStrings.text("delete", language),role:.destructive){try? pack.remove()}
                Button(SariUIStrings.text("cancel", language),role:.cancel){}
            } message:{Text(SariUIStrings.text("redownload_later",language))}
        }
    }
}
