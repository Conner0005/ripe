#!/bin/bash
# Publishes the committed site/ folder to the gh-pages branch, which GitHub Pages serves at
# https://conner0005.github.io/ripe/. Run after committing changes to site/.
set -euo pipefail
cd "$(dirname "$0")/.."

git subtree push --prefix site origin gh-pages
