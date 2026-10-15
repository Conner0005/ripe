#!/bin/bash
# Builds a universal build/Ripe.app and zips it as build/Ripe.zip for a GitHub Release.
# The name has no version so https://github.com/Conner0005/ripe/releases/latest/download/Ripe.zip always works.
set -euo pipefail
cd "$(dirname "$0")/.."

UNIVERSAL=1 scripts/bundle.sh

ZIP=build/Ripe.zip
rm -f "$ZIP"
ditto -c -k --keepParent build/Ripe.app "$ZIP"

echo "Built $ZIP"
