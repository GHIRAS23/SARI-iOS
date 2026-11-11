# SARI iOS runtime crash fix — 2026-08-27

Crash report diagnosis:
- Exception: EXC_BREAKPOINT / SIGTRAP
- Faulting queue: com.apple.usernotifications.UNUserNotificationServiceConnection.call-out
- App frame: closure #1 in PrayerStore.requestNotifications()
- Root cause: a Swift 6 main-actor-isolated completion closure was invoked by UserNotifications on its callback queue, triggering a dispatch actor-isolation assertion.

Fixes applied:
1. PrayerStore.requestNotifications now uses the async requestAuthorization API inside a MainActor Task instead of the legacy completion-handler API.
2. CompassStore CLLocationManagerDelegate callback is nonisolated and forwards Sendable scalar values to MainActor.
3. NetworkState NWPathMonitor callback is routed through a nonisolated helper and forwards only a Bool to MainActor.

Validation performed in this environment:
- swiftc -parse passed for every Swift file under SARI and SARIWidget.
- Only the three source files above were changed relative to BUILD-READY final v3, plus this note.

Final compile/runtime verification still requires Xcode/GitHub Actions and a real iPhone because this environment is not macOS/iOS.
