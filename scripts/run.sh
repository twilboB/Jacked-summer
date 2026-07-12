#!/usr/bin/env bash
# Build Jacked by Summer and launch it on an iOS Simulator.
set -euo pipefail

SCHEME="JackedBySummer"
BUNDLE_ID="com.jackedbysummer.app"
cd "$(dirname "$0")/.."

DEVICE="${DEVICE:-$(xcrun simctl list devices available | grep -Eo 'iPhone [0-9]+[^(]*' | head -1 | sed 's/ *$//')}"
DEVICE="${DEVICE:-iPhone 16 Pro}"
echo "==> Building for: $DEVICE"

DERIVED="build/DerivedData"
xcodebuild build \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED"

APP_PATH="$(find "$DERIVED/Build/Products" -name 'JackedBySummer.app' -type d | head -1)"
echo "==> App: $APP_PATH"

echo "==> Booting simulator"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator || true
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted "$BUNDLE_ID"
echo "==> Launched $BUNDLE_ID"
