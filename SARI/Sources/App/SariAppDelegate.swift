import UIKit
import UserNotifications

/// Ensures local prayer notifications still present (including custom Adhan sound)
/// while SARI is open in the foreground. Without a notification-center delegate,
/// iOS normally suppresses local notification presentation for the foreground app.
final class SariAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
