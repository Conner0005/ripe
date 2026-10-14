#!/bin/bash
# Builds a release binary and wraps it into build/Ripe.app (menu-bar-only, ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

# UNIVERSAL=1 builds for both Apple silicon and Intel Macs (needs Xcode), as used by release.sh.
if [[ "${UNIVERSAL:-}" == 1 ]]; then
    swift build -c release --product Pomodoro --arch arm64 --arch x86_64
    BIN=.build/apple/Products/Release/Pomodoro
else
    swift build -c release --product Pomodoro
    BIN=.build/release/Pomodoro
fi

APP=build/Ripe.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pomodoro"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "Built $APP"
