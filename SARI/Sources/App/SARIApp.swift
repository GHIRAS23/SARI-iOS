import SwiftUI

@main
struct SARIApp: App {
    @UIApplicationDelegateAdaptor(SariAppDelegate.self) private var appDelegate
    @StateObject private var prayer = PrayerStore()
    @StateObject private var fiqhPack = LocalFiqhPack.shared
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
                            Task { await fiqhPack.resumeBackgroundWorkIfNeeded() }
                        }
                } else {
                    SariOnboardingView(completed: $onboardingCompleted)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard onboardingCompleted else { return }
                switch phase {
                case .active:
                    prayer.start()
                    prayer.refreshForToday()
                    Task { await fiqhPack.resumeBackgroundWorkIfNeeded() }
                case .background:
                    // The URLSession background transfer is independent of the loaded
                    // LLM. Releasing the model here lowers memory pressure while SARI
                    // is suspended; it is loaded again on the next question.
                    Task { await LocalFiqhEngine.shared.releaseModelIfIdle() }
                default:
                    break
                }
            }
        }
    }
}
