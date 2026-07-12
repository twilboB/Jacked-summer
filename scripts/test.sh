#!/usr/bin/env bash
# Run the Jacked by Summer test suite (unit + UI) on an iOS Simulator.
#
# Requires the JackedBySummerTests and JackedBySummerUITests targets to exist in
# the Xcode project — see Tests/SETUP.md (a ~2 minute one-time step in Xcode).
set -euo pipefail

SCHEME="JackedBySummer"
cd "$(dirname "$0")/.."

# Pick the first available iPhone simulator, or override with DEVICE env var.
DEVICE="${DEVICE:-$(xcrun simctl list devices available | grep -Eo 'iPhone [0-9]+[^(]*' | head -1 | sed 's/ *$//')}"
DEVICE="${DEVICE:-iPhone 16 Pro}"
echo "==> Testing on: $DEVICE"

xcodebuild test \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -resultBundlePath "build/TestResults.xcresult" \
  -only-testing:JackedBySummerTests \
  -only-testing:JackedBySummerUITests \
  | xcbeautify 2>/dev/null || \
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -resultBundlePath "build/TestResults.xcresult"

echo "==> Results: build/TestResults.xcresult (open in Xcode for details)"
