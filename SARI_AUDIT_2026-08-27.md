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

## Build #6 full-log follow-up
- Reviewed the complete 823-line Xcode build log from commit `97fcde5`.
- The only explicit Swift compiler diagnostics were two references to an out-of-scope `language` identifier in `QuranView.swift` (lines 290 and 319 in that build).
- Replaced both with `SariLanguage.selected`.
- Re-ran Swift parser validation across every `.swift` file under `SARI` and `SARIWidget`: no syntax errors.
- The log contained no `warning:` diagnostics from Swift/Xcode. `exit code 65` is the build result, not an independent source-code error.

## Final build-readiness pass (latest 951-line Xcode log)
- Reviewed the latest Xcode 16.4 / Swift 6 build log through its terminal failure.
- The Swift sources and SwiftLlama package compiled, the application linked, the widget linked and embedded, and the failure occurred at `ValidateEmbeddedBinary` because the host app bundle had no processed `Info.plist`.
- Added deterministic `Info.plist` generation/configuration for both the host application and WidgetKit extension through XcodeGen.
- Added the widget `NSExtensionPointIdentifier = com.apple.widgetkit-extension` and synchronized host/widget marketing/build versions.
- Changed app and widget resource declarations to explicit `buildPhase: resources` source entries so JSON, audio, notification sounds, shared scholar data, and privacy manifests are included deterministically.
- Added a bundle-resource lookup fallback (requested subdirectory first, bundle root second) for Quran, adhkar, UI strings, scholar data, and adhan preview audio.
- Pinned SwiftLlama to exact version `0.1.0` and pinned CI to Xcode 16.4 on `macos-15`.
- CI now validates source plists/entitlements/privacy manifests, generated Info.plist build settings, critical resource references, built host/widget Info.plists, bundle identifiers, WidgetKit extension point, matching build versions, and presence of critical bundled resources before creating the IPA.

## Final local validation after the pass
- 41 Swift files pass `swiftc -parse` with Swift 6.2.1.
- `project.yml` and the GitHub Actions workflow parse as YAML.
- All 50 JSON files parse successfully.
- All 6 plist/privacy/entitlement files parse successfully.
- Quran dataset contains 6,236 unique ayah IDs.
- UI string catalog contains 312 keys.
- Scholar dataset contains 17 entries.
- All 8 GitHub Actions shell `run:` blocks pass `bash -n` syntax validation after substituting the GitHub expression placeholder used for runner temp paths.

## External runtime items not fixable from source alone
These do not prevent the unsigned Xcode/GitHub build, but they prevent claiming the *entire product* is production-ready:
- `SARI_API_BASE_URL` is still a placeholder because no public production backend URL was supplied.
- The local fiqh pack is not deployable yet: the repository contains a manifest template with placeholder hosting/checksums and no bundled `.gguf` model or `fiqh_pages.sqlite3`. A real HTTPS manifest URL, hosted model/database, exact byte sizes, and SHA-256 values are still required.
- The repository currently has no AppIcon asset catalog. This does not explain the current compile/build failure, but an App Store-ready submission needs final app icon assets.
