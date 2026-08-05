#!/bin/bash
# Assembles SalaryTicker.app from the SwiftPM executable.
#   ./Packaging/build_app.sh            build into ./SalaryTicker.app
#   ./Packaging/build_app.sh install    also copy into /Applications and relaunch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/SalaryTicker.app"

echo "==> swift build -c release"
swift build -c release --package-path "$ROOT"
BIN_DIR="$(swift build -c release --package-path "$ROOT" --show-bin-path)"

# The icon is drawn by the app itself, so it is generated here rather than committed:
# a checked-in .icns can drift from the code that draws it, and this cannot.
echo "==> rendering app icon"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
if "$BIN_DIR/SalaryTicker" --render-appicon "$ICONSET" >/dev/null &&
   iconutil -c icns "$ICONSET" -o "$ROOT/Packaging/AppIcon.icns"; then
	echo "    ok"
else
	echo "    WARNING: icon rendering failed; the bundle will use the generic app icon" >&2
fi
rm -rf "$(dirname "$ICONSET")"

echo "==> assembling $(basename "$APP")"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SalaryTicker" "$APP/Contents/MacOS/SalaryTicker"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
[ -f "$ROOT/Packaging/AppIcon.icns" ] && cp "$ROOT/Packaging/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: enough for a locally built app, and gives the login item
# a stable-enough identity for SMAppService.
echo "==> codesign (ad-hoc)"
codesign --force --sign - "$APP"

if [[ "${1:-}" == "install" ]]; then
	echo "==> installing to /Applications"
	pkill -x SalaryTicker || true
	rm -rf "/Applications/SalaryTicker.app"
	cp -R "$APP" "/Applications/SalaryTicker.app"
	open "/Applications/SalaryTicker.app"
	echo "Installed and launched: /Applications/SalaryTicker.app"
else
	echo "Built: $APP"
	echo "Try it:  open '$APP'"
	echo "Install: $0 install"
fi
