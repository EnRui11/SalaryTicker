#!/bin/bash
# Builds the phone and watch apps and runs them on the simulators.
#
#   ./Packaging/build_ios.sh          build the phone app, which carries the watch app
#   ./Packaging/build_ios.sh run      also install and launch it on the iPhone simulator
#   ./Packaging/build_ios.sh watch    build and launch the watch app on the paired watch
#   ./Packaging/build_ios.sh both     the pair, phone first
#
# DEVICE names the iPhone simulator. The watch is not named: it is looked up from the
# pairing, because WatchConnectivity only exists between a phone and the watch it is
# actually paired with, so any other watch would launch and then sit there empty.
#
# Simulator only. There is no signing identity on this machine, so a real device needs an
# Apple ID added in Xcode first -- and that gives a profile that expires after seven days.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${DEVICE:-iPhone 17}"
PHONE_BUNDLE="com.steve.salaryticker.mobile"
WATCH_BUNDLE="com.steve.salaryticker.mobile.watchkitapp"
DERIVED="$ROOT/.build/ios"
PRODUCTS="$DERIVED/Build/Products"

command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }

# The project is generated rather than committed, for the same reason the app icon is: it
# is output, and a checked-in copy drifts from project.yml, which is the thing that says
# what the app is.
generate() {
	echo "==> generating SalaryTickerMobile.xcodeproj from project.yml"
	xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT" >/dev/null
}

build() { # scheme, destination
	echo "==> building $1"
	xcodebuild -project "$ROOT/SalaryTickerMobile.xcodeproj" \
		-scheme "$1" -destination "$2" -derivedDataPath "$DERIVED" build >/dev/null
}

# Resolved by udid rather than by name throughout. `simctl ... booted` picks whichever
# device happens to be booted, and with a phone and a watch both running that is a coin
# toss; a name is ambiguous the moment "iPhone 17" and "iPhone 17 Pro" both exist.
udid() { # device name
	xcrun simctl list devices available -j | python3 -c '
import json, sys
wanted = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if device["name"] == wanted:
            print(device["udid"])
            sys.exit(0)
sys.exit(f"no simulator named {wanted!r}; xcrun simctl list devices available")
' "$1"
}

paired_watch() { # phone udid
	xcrun simctl list pairs -j | python3 -c '
import json, sys
phone = sys.argv[1]
for pair in json.load(sys.stdin)["pairs"].values():
    if pair["phone"]["udid"] == phone:
        print(pair["watch"]["udid"], pair["watch"]["name"], sep="\t")
        sys.exit(0)
sys.exit("no watch is paired with that iPhone; pair one in Simulator > Device")
' "$1"
}

# `bootstatus -b` boots if needed and then waits for the device to finish coming up.
# Installing into a half-booted simulator fails in ways that read like a build problem.
boot() { # udid
	xcrun simctl bootstatus "$1" -b >/dev/null
}

run_phone() {
	local phone app
	phone="$(udid "$DEVICE")"
	app="$PRODUCTS/Debug-iphonesimulator/SalaryTickerMobile.app"
	echo "==> $DEVICE"
	boot "$phone"
	open -a Simulator
	xcrun simctl install "$phone" "$app"
	xcrun simctl launch "$phone" "$PHONE_BUNDLE" >/dev/null
	echo "Launched on $DEVICE."
}

run_watch() {
	local phone watch name app
	phone="$(udid "$DEVICE")"
	IFS=$'\t' read -r watch name < <(paired_watch "$phone")
	app="$PRODUCTS/Debug-watchsimulator/SalaryTickerWatch.app"
	echo "==> $name"
	# The phone first and on purpose. The watch app holds no settings of its own; it waits
	# for the phone to send them, and a watch booted alone shows the empty state instead.
	boot "$phone"
	boot "$watch"
	open -a Simulator
	xcrun simctl install "$watch" "$app"
	xcrun simctl launch "$watch" "$WATCH_BUNDLE" >/dev/null
	echo "Launched on $name."
}

generate

case "${1:-build}" in
build)
	build SalaryTickerMobile "platform=iOS Simulator,name=$DEVICE"
	echo "Built: $PRODUCTS/Debug-iphonesimulator/SalaryTickerMobile.app"
	echo "Run it:  $0 run"
	;;
run)
	build SalaryTickerMobile "platform=iOS Simulator,name=$DEVICE"
	run_phone
	;;
watch)
	build SalaryTickerWatch "platform=watchOS Simulator,id=$(paired_watch "$(udid "$DEVICE")" | cut -f1)"
	run_watch
	;;
both)
	build SalaryTickerMobile "platform=iOS Simulator,name=$DEVICE"
	run_phone
	build SalaryTickerWatch "platform=watchOS Simulator,id=$(paired_watch "$(udid "$DEVICE")" | cut -f1)"
	run_watch
	;;
*)
	echo "usage: $0 [build|run|watch|both]" >&2
	exit 1
	;;
esac
