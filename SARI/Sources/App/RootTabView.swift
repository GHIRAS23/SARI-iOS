import SwiftUI

struct RootTabView:View {
    @AppStorage("sariLanguage") private var languageRaw=""
    @AppStorage("sariAppearance") private var appearanceRaw="system"
    private var language:SariLanguage { SariLanguage(rawValue:languageRaw) ?? SariLanguage.device }
    var body:some View {
        TabView {
            HomeView().tabItem { Label(SariStrings.t("home",language),systemImage:"house.fill") }
            QuranView().tabItem { Label(SariStrings.t("quran",language),systemImage:"book.closed.fill") }
            FiqhAssistantView().tabItem { Label(SariStrings.t("ask",language),systemImage:"sparkles") }
            TravelView().tabItem { Label(SariStrings.t("travel",language),systemImage:"airplane") }
            SettingsView().tabItem { Label(SariStrings.t("more",language),systemImage:"ellipsis.circle.fill") }
        }
        .tint(SariDesign.emerald)
        .preferredColorScheme(SariAppearance(rawValue:appearanceRaw)?.scheme)
    }
}
