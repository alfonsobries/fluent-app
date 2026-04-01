#!/bin/bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: ./scripts/notarize.sh <path-to-dmg-or-zip>"
  exit 1
fi

if [[ -z "${APPLE_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
  echo "APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD and APPLE_TEAM_ID are required."
  exit 1
fi

ARTIFACT_PATH="$1"

xcrun notarytool submit "$ARTIFACT_PATH" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait

xcrun stapler staple "$ARTIFACT_PATH"

echo "Notarization complete for $ARTIFACT_PATH"
