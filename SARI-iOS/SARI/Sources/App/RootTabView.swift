import SwiftUI

private enum SariRootTab: Hashable {
    case home, quran, ask, travel, settings
}

struct RootTabView: View {
    @EnvironmentObject private var prayer: PrayerStore
    @AppStorage("sariLanguage") private var languageRaw = ""
    @AppStorage("sariAppearance") private var appearanceRaw = "system"
    @State private var selectedTab: SariRootTab = .home

    private var language: SariLanguage {
        SariLanguage(rawValue: languageRaw) ?? SariLanguage.device
    }

    private var languageIdentity: String {
        languageRaw.isEmpty ? "device-\(language.rawValue)" : languageRaw
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(SariRootTab.home)
                .tabItem { Label(SariStrings.t("home", language), systemImage: "house.fill") }
            QuranView()
                .tag(SariRootTab.quran)
                .tabItem { Label(SariStrings.t("quran", language), systemImage: "book.closed.fill") }
            FiqhAssistantView()
                .tag(SariRootTab.ask)
                .tabItem { Label(SariStrings.t("ask", language), systemImage: "sparkles") }
            TravelView()
                .tag(SariRootTab.travel)
                .tabItem { Label(SariStrings.t("travel", language), systemImage: "airplane") }
            SettingsView()
                .tag(SariRootTab.settings)
                .tabItem { Label(SariStrings.t("more", language), systemImage: "ellipsis.circle.fill") }
        }
        // Force the currently visible hierarchy to re-render immediately, while the explicit
        // selection binding keeps the user on the same tab during a language switch.
        .id(languageIdentity)
        .sariLanguageEnvironment(language)
        .tint(SariDesign.emerald)
        .preferredColorScheme(SariAppearance(rawValue: appearanceRaw)?.scheme)
        .onChange(of: languageRaw) { _, _ in
            prayer.refreshForLanguage()
        }
    }
}
