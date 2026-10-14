#!/bin/bash
# Builds a universal build/Ripe.app and zips it as build/Ripe-<version>.zip for a GitHub Release.
set -euo pipefail
cd "$(dirname "$0")/.."

UNIVERSAL=1 scripts/bundle.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
ZIP=build/Ripe-$VERSION.zip
rm -f "$ZIP"
ditto -c -k --keepParent build/Ripe.app "$ZIP"

echo "Built $ZIP"
