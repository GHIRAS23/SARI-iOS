# SARI — iPhone Build Path

## Current state
The iOS source passed the prior static QA gate. This package is prepared for an iPhone-first build.

## On a macOS build machine
1. Install Xcode and XcodeGen.
2. Run `scripts/build_ios_device.sh` to generate the Xcode project, resolve SwiftLlama, and compile for a generic iOS device without signing.
3. Open `SARI.xcodeproj` in Xcode.
4. Select your Apple Developer Team for both **SARI** and **SARIWidgetExtension**.
5. Ensure the App Group `group.sa.sari.app` exists for the App ID and Widget App ID.
6. Build to your connected iPhone, or Archive and distribute with TestFlight.

## Signing values that must belong to the developer account
- App bundle ID: `sa.sari.app`
- Widget bundle ID: `sa.sari.app.widget`
- App Group: `group.sa.sari.app`

These identifiers may need to be changed if they are already registered by another Apple developer account.

## Before TestFlight
Replace `https://YOUR-SARI-BACKEND.example` if any server-backed feature is intended to be enabled. The local fiqh path can remain independent where implemented.

## Device QA
Use `DEVICE_QA_HANDOFF.md` and `DEVICE_QA_CHECKLIST.md` after installation.
