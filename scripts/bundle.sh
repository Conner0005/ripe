#!/bin/bash
# Builds a release binary and wraps it into build/Pomodoro.app (menu-bar-only, ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product Pomodoro

APP=build/Pomodoro.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Pomodoro "$APP/Contents/MacOS/Pomodoro"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "Built $APP"
