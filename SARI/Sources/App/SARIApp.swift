import SwiftUI

@main
struct SARIApp: App {
    @UIApplicationDelegateAdaptor(SariAppDelegate.self) private var appDelegate
    @StateObject private var prayer = PrayerStore()
    @AppStorage("sariOnboardingCompleted") private var onboardingCompleted = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingCompleted {
                    RootTabView()
                        .environmentObject(prayer)
                        .onAppear {
                            prayer.start()
                            prayer.requestNotifications()
                        }
                } else {
                    SariOnboardingView(completed: $onboardingCompleted)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard onboardingCompleted, phase == .active else { return }
                prayer.start()
                prayer.refreshForToday()
            }
        }
    }
}
