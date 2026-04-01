#!/bin/bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: ./scripts/release.sh <version>"
  exit 1
fi

VERSION="$1"
TAG="v$VERSION"
DMG_NAME="FluentApp-${VERSION}.dmg"

./scripts/test_coverage.sh
VERSION="$VERSION" ./build_dmg.sh

if [[ ! -f "$DMG_NAME" ]]; then
  echo "Missing artifact: $DMG_NAME"
  exit 1
fi

git tag -a "$TAG" -m "Release $VERSION"
git push origin "$TAG"

if command -v gh >/dev/null 2>&1; then
  gh release create "$TAG" "$DMG_NAME" "$DMG_NAME.sha256" \
    --title "FluentApp $VERSION" \
    --generate-notes
else
  echo "Tag pushed. Create the GitHub release manually and upload:"
  echo "  $DMG_NAME"
  echo "  $DMG_NAME.sha256"
fi
