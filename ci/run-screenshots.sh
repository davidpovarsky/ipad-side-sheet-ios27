#!/bin/bash
set -euo pipefail

BUNDLE_ID="com.davidpovarsky.sidesheetlab"
mkdir -p screenshots/ipad screenshots/iphone logs results

echo "=== Xcode and SDK ==="
xcodebuild -version
xcodebuild -showsdks
xcrun simctl list devices available

# Pick real iOS 27 iPad and iPhone simulator devices. Never substitute an iPhone
# screenshot for an actual iPad window resizing result.
python3 - <<'PY'
import json, os, subprocess, sys
data = json.loads(subprocess.check_output(["xcrun","simctl","list","devices","available","-j"], text=True))
candidates = []
for runtime, devices in data["devices"].items():
    if "iOS-27" not in runtime:
        continue
    for device in devices:
        if not device.get("isAvailable", True):
            continue
        candidates.append((device["name"], device["udid"], runtime))
if not candidates:
    sys.exit("No iOS 27 simulator available on this runner; not silently substituting an older SDK.")
def select(key):
    matches = [entry for entry in candidates if key in entry[0]]
    if not matches:
        return None
    matches.sort(key=lambda e: (not ("Pro" in e[0]), not ("13-inch" in e[0])))
    return matches[0]
ipad = select("iPad")
iphone = select("iPhone")
if not ipad:
    sys.exit("No iPadOS 27 simulator available on this runner.")
print("iPad selection:", ipad)
print("iPhone selection:", iphone)
with open(os.environ["GITHUB_ENV"], "a") as f:
    f.write("IPAD_UDID=" + ipad[1] + "\n")
    if iphone:
        f.write("IPHONE_UDID=" + iphone[1] + "\n")
with open("logs/simulators.txt", "w") as f:
    for name, udid, runtime in candidates:
        f.write(f"{name}\t{udid}\t{runtime}\n")
PY

# GITHUB_ENV additions become visible only in the NEXT GitHub Actions step.
# For this script, pick the same simulator IDs again directly.
IPAD_UDID="$(python3 - <<'PY'
import json,subprocess
d=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j'],text=True))
matches=[(x['name'],x['udid']) for runtime,devices in d['devices'].items() if 'iOS-27' in runtime for x in devices if 'iPad' in x['name'] and x.get('isAvailable',True)]
matches.sort(key=lambda x:(not ('Pro' in x[0]),not ('13-inch' in x[0])))
print(matches[0][1])
PY
)"
IPHONE_UDID="$(python3 - <<'PY'
import json,subprocess
d=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j'],text=True))
matches=[(x['name'],x['udid']) for runtime,devices in d['devices'].items() if 'iOS-27' in runtime for x in devices if 'iPhone' in x['name'] and x.get('isAvailable',True)]
matches.sort(key=lambda x:not ('Pro' in x[0]))
print(matches[0][1] if matches else '')
PY
)"

echo "=== Build actual iOS 27 simulator app ==="
if ! xcodebuild -project SideSheetLab.xcodeproj -scheme SideSheetLab -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$PWD/DerivedData" \
    CODE_SIGNING_ALLOWED=NO build > logs/build.log 2>&1; then
    tail -n 130 logs/build.log
    exit 1
fi
APP="$PWD/DerivedData/Build/Products/Debug-iphonesimulator/SideSheetLab.app"
test -d "$APP"

capture_device() {
    local udid="$1"
    local kind="$2"
    echo "=== Capture native sheet on $kind / $udid ==="
    xcrun simctl boot "$udid" || true
    xcrun simctl bootstatus "$udid" -b
    xcrun simctl status_bar "$udid" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100 || true
    xcrun simctl install "$udid" "$APP"
    for detent in peek half full; do
        xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
        xcrun simctl launch "$udid" "$BUNDLE_ID" --detent "$detent" | tee "logs/${kind}-${detent}-launch.txt"
        sleep 7
        xcrun simctl io "$udid" screenshot "screenshots/$kind/${kind}-native-${detent}.png"
        sips -g pixelWidth -g pixelHeight "screenshots/$kind/${kind}-native-${detent}.png"
    done
}

capture_device "$IPAD_UDID" "ipad"
if [ "${INCLUDE_IPHONE:-0}" = "1" ] && [ -n "$IPHONE_UDID" ]; then
    capture_device "$IPHONE_UDID" "iphone"
else
    echo "Skipping the ~10-minute extra iPhone simulator boot; only iPad screenshots requested for the fast run."
fi

# CI default: publish raw, genuine device screenshots immediately. Slow XCTest
# landscape + window-resize runs can be enabled with RUN_UI_TESTS=1 after the
# first evidence has been captured; this avoids long headless UITest hangs.
if [ "${RUN_UI_TESTS:-0}" != "1" ]; then
    echo "Skipping extended XCTest so screenshots can be uploaded immediately."
    cat > screenshots/README.txt <<'EOF'
Real iPadOS 27 simulator screenshot captures, not mockups. iPhone is optional.
ipad/ipad-native-peek.png: actual iPad, small native sheet.
ipad/ipad-native-half.png: actual iPad, medium native sheet.
ipad/ipad-native-full.png: actual iPad, large native sheet.
iphone/: optional reference of native iPhone sheet adaptation, NOT a resized iPad.
A physically resized iPad window remains unverified until separately tested.
EOF
    exit 0
fi

# XCTest rotates a real iPad simulator to landscape and records each native
# presentation inside the xcresult, alongside the physical window frame.
run_ui_tests() {
    local udid="$1"
    local kind="$2"
    echo "=== XCTest on $kind ==="
    local status=0
    xcodebuild test \
        -project SideSheetLab.xcodeproj -scheme SideSheetLab \
        -destination "platform=iOS Simulator,id=$udid" \
        -parallel-testing-enabled NO \
        -resultBundlePath "$PWD/results/$kind.xcresult" \
        -derivedDataPath "$PWD/DerivedData" \
        CODE_SIGNING_ALLOWED=NO \
        -only-testing:SideSheetUITests/NativeSheetTests \
        > "logs/${kind}-ui-tests.log" 2>&1 || status=$?
    tail -n 80 "logs/${kind}-ui-tests.log"
    if [ -d "results/$kind.xcresult" ]; then
        xcrun xcresulttool export attachments \
            --path "results/$kind.xcresult" \
            --output-path "screenshots/$kind/ui-test-attachments" || true
    fi
    return "$status"
}
status=0
run_ui_tests "$IPAD_UDID" "ipad" || status=1
if [ "${INCLUDE_IPHONE:-0}" = "1" ] && [ -n "$IPHONE_UDID" ]; then
    run_ui_tests "$IPHONE_UDID" "iphone" || status=1
fi

cat > screenshots/README.txt <<'EOF'
ALL screenshots are from the real iOS 27 simulator, NOT mockups.

ipad/ipad-native-peek.png : Actual iPad simulator, small native sheet.
ipad/ipad-native-half.png : Actual iPad simulator, medium native sheet.
ipad/ipad-native-full.png : Actual iPad simulator, full-height native sheet.
ipad/ui-test-attachments/ : iPad landscape UI test screenshots, if tests succeed.
iphone/ : iPhone simulator reference for adaptive bottom-sheet behavior ONLY.

IMPORTANT: iPhone screenshots do NOT prove that a narrow window on the
same iPad changes to a bottom sheet. That requires physically resizing an
iPadOS window; this workflow currently captures iPad and iPhone devices and
reports this gap honestly. The iPad window size is printed by the UI tests.
EOF
if [ "$status" -ne 0 ]; then
    echo "Some UI tests failed. Check logs and screenshots artifacts."
    exit "$status"
fi
echo "Captured native sheet screenshots and UI test attachments."
