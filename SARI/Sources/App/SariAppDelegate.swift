import UIKit
import UserNotifications

/// Dedicated notification-center delegate.
///
/// Keep this object separate from UIApplicationDelegate. UIApplicationDelegate is
/// main-actor isolated in Swift 6, while UNUserNotificationCenterDelegate callbacks
/// are imported as nonisolated. Mixing both conformances in one class triggers the
/// Swift 6/Xcode 16.4 "non-sendable parameter ... into main actor-isolated
/// implementation" build error.
final class SariNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Present prayer notifications and play their custom Adhan sound even when
        // SARI is currently open in the foreground.
        completionHandler([.banner, .list, .sound])
    }
}

@MainActor
final class SariAppDelegate: NSObject, UIApplicationDelegate {
    // UNUserNotificationCenter keeps its delegate weakly, so the app delegate must
    // strongly retain this object for the lifetime of the process.
    private let notificationDelegate = SariNotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}
