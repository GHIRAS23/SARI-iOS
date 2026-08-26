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
                    Picker(SariUIStrings.text("app_language", SariLanguage.selected),selection:$languageRaw) {
                        Text(SariUIStrings.format("automatic_device",SariLanguage.selected,["value":SariLanguage.device.displayName])).tag("")
                        ForEach(SariLanguage.allCases){l in Text(l.displayName).tag(l.rawValue)}
                    }
                } header:{Text(SariUIStrings.text("language", SariLanguage.selected))}
                  footer:{Text(SariUIStrings.text("settings_language_note", SariLanguage.selected))}

                Section(language.isArabic ? SariUIStrings.text("date",SariLanguage.selected):"Date") {
                    NavigationLink { CalendarSettingsView() } label:{Label(language.isArabic ? SariUIStrings.text("calendar_date", SariLanguage.selected):"Calendar & date",systemImage:"calendar")}
                }

                Section(language.isArabic ? SariUIStrings.text("appearance", SariLanguage.selected):"Appearance") {
                    Picker(language.isArabic ? SariUIStrings.text("theme",SariLanguage.selected):"Theme",selection:$appearanceRaw) {
                        ForEach(SariAppearance.allCases){a in Text(a.title(language)).tag(a.rawValue)}
                    }
                }

                Section(SariUIStrings.text("worship", SariLanguage.selected)) {
                    NavigationLink { PrayerSettingsView() } label:{Label(SariUIStrings.text("prayer_adhan_iqama",SariLanguage.selected),systemImage:"bell.badge.fill")}
                    NavigationLink { AdhkarView() } label:{Label(SariUIStrings.text("adhkar", SariLanguage.selected),systemImage:"heart.fill")}
                }

                Section(SariUIStrings.text("local_fiqh", SariLanguage.selected)) {
                    if pack.installed {
                        Label(SariUIStrings.format("pack_installed_version",language,["value":pack.installedVersion.map{" — \($0)"} ?? ""]),systemImage:"checkmark.seal.fill").foregroundStyle(.green)
                        Button(role:.destructive){showDelete=true}label:{Label(SariUIStrings.text("delete_assistant_pack",SariLanguage.selected),systemImage:"trash")}
                    } else {
                        NavigationLink { FiqhPackSetupView() } label:{Label(SariUIStrings.text("download_assistant_pack", SariLanguage.selected),systemImage:"arrow.down.circle.fill")}
                    }
                }
            }
            .navigationTitle(SariStrings.t("settings",language))
            .tint(SariDesign.emerald)
            .scrollContentBackground(.hidden)
            .background(LinearGradient(colors:[SariDesign.mint.opacity(0.35),Color(.systemBackground)],startPoint:.top,endPoint:.bottom))
            .confirmationDialog(SariUIStrings.text("delete_assistant_files",SariLanguage.selected),isPresented:$showDelete,titleVisibility:.visible) {
                Button(SariUIStrings.text("delete", SariLanguage.selected),role:.destructive){try? pack.remove()}
                Button(SariUIStrings.text("cancel", SariLanguage.selected),role:.cancel){}
            } message:{Text(SariUIStrings.text("redownload_later",SariLanguage.selected))}
        }
    }
}
