#!/bin/bash
# Builds the iPhone app and runs it on a booted simulator.
#   ./Packaging/build_ios.sh              build only
#   ./Packaging/build_ios.sh run          build, install and launch
#
# Simulator only. There is no signing identity on this machine, so a real device needs an
# Apple ID added in Xcode first — and that gives a profile that expires after seven days.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${DEVICE:-iPhone 17}"
BUNDLE_ID="com.steve.salaryticker.mobile"

command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }

# The project is generated rather than committed, for the same reason the app icon is: it
# is output, and a checked-in copy drifts from project.yml, which is the thing that says
# what the app is.
echo "==> generating SalaryTickerMobile.xcodeproj from project.yml"
xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT" >/dev/null

echo "==> building for the $DEVICE simulator"
xcodebuild -project "$ROOT/SalaryTickerMobile.xcodeproj" \
	-scheme SalaryTickerMobile \
	-destination "platform=iOS Simulator,name=$DEVICE" \
	-derivedDataPath "$ROOT/.build/ios" \
	build >/dev/null

APP="$ROOT/.build/ios/Build/Products/Debug-iphonesimulator/SalaryTickerMobile.app"
echo "Built: $APP"

if [[ "${1:-}" == "run" ]]; then
	xcrun simctl bootstatus booted >/dev/null 2>&1 || xcrun simctl boot "$DEVICE"
	xcrun simctl install booted "$APP"
	xcrun simctl launch booted "$BUNDLE_ID"
	echo "Launched on $DEVICE."
else
	echo "Run it:  $0 run"
fi
