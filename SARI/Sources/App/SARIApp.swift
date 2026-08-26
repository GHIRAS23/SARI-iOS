import SwiftUI
@main struct SARIApp:App {
    @StateObject private var prayer=PrayerStore()
    @AppStorage("sariOnboardingCompleted") private var onboardingCompleted=false
    var body:some Scene {
        WindowGroup {
            Group {
                if onboardingCompleted { RootTabView().environmentObject(prayer).onAppear{prayer.requestNotifications()} }
                else { SariOnboardingView(completed:$onboardingCompleted) }
            }
        }
    }
}
