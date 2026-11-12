#!/bin/bash
set -euo pipefail

command -v xcodegen >/dev/null 2>&1 || { echo "Install XcodeGen first: brew install xcodegen"; exit 2; }
command -v xcodebuild >/dev/null 2>&1 || { echo "Xcode is required."; exit 2; }

cd "$(dirname "$0")/.."
xcodegen generate

echo "== Resolving Swift packages =="
xcodebuild -project SARI.xcodeproj -scheme SARI -resolvePackageDependencies

echo "== Building unsigned device archive for compile verification =="
xcodebuild \
  -project SARI.xcodeproj \
  -scheme SARI \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "Compile verification complete."
echo "For installation/TestFlight, sign with your Apple Developer team in Xcode or CI."
