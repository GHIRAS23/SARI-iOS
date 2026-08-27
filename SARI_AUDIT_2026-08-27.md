# SARI iOS pre-build audit — 2026-08-27

## Scope
Static audit for Swift 6 / Xcode 16.4 / GitHub Actions build readiness.

## Applied fixes
- Fixed Swift 6 compile issues in CalendarSettingsView.swift.
- Fixed LocalFiqhPack.swift comparison syntax.
- Fixed LocalFiqhSearch.swift closure syntax and SQLite transient destructor binding.
- Kept prior Swift 6 fixes in FiqhAPI, PrayerService, SariCalendar, SariUIStrings, and QiblaView.
- Added base NSLocationWhenInUseUsageDescription build setting.
- Added app privacy manifest to the application target resources.
- Added widget privacy manifest and App Group UserDefaults required-reason declaration.
- Declared UserDefaults and disk-space required-reason API use in the app privacy manifest.
- Updated GitHub Actions checkout/upload-artifact actions to Node 24-capable major versions and added read-only contents permission.
- Added .gitignore for Xcode, SwiftPM, signing material, secrets, generated Xcode project, IPA/archive outputs.

## Checks completed
- All 40 Swift files pass Swift 6.2 parser syntax checking on Linux.
- project.yml parses as valid YAML.
- GitHub Actions workflow parses as valid YAML.
- Both PrivacyInfo.xcprivacy files pass plist validation.
- No obvious tracked signing keys, .env files, mobileprovision files, or private-key material found in the supplied archive.
- Known Build #5 source patterns (SQLITE_TRANSIENT, malformed map closure, ==.orderedSame) no longer remain.

## Final gates that require macOS/Xcode/GitHub
- XcodeGen project generation.
- Swift package resolution for SwiftLlama.
- Full Swift 6 type checking against Apple SDKs.
- Link and app-extension embedding.
- Unsigned generic iOS device build.
- Signed device/App Store build with the user's Apple Developer signing assets.

## Runtime configuration still required
SARI_API_BASE_URL is intentionally a placeholder in project.yml. Online fiqh/backend functionality remains unconfigured until a real HTTPS backend URL is supplied.
