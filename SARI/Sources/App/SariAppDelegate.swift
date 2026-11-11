import UIKit
import UserNotifications

/// Dedicated notification-center delegate.
///
/// Keep this object separate from UIApplicationDelegate. UIApplicationDelegate is
/// main-actor isolated in Swift 6, while UNUserNotificationCenterDelegate callbacks
/// are imported as nonisolated. Mixing both conformances in one class triggers the
/// Swift 6/Xcode 16.4 actor-isolation build error.
final class SariNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

@MainActor
final class SariAppDelegate: NSObject, UIApplicationDelegate {
    // UNUserNotificationCenter keeps its delegate weakly, so retain it for the
    // lifetime of the process.
    private let notificationDelegate = SariNotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        ResumableFileDownloader.shared.prepareBackgroundSession()
        return true
    }

    /// Required for URLSessionConfiguration.background. iOS may relaunch SARI after
    /// a suspended 2.1 GB model transfer finishes. The downloader calls this handler
    /// only after all background-session delegate events have been delivered.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == ResumableFileDownloader.backgroundSessionIdentifier else {
            completionHandler()
            return
        }
        ResumableFileDownloader.shared.setBackgroundCompletionHandler(completionHandler)
    }
}
