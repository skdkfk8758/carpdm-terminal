#!/bin/zsh
set -euo pipefail

: "${APPLE_ID:?Missing APPLE_ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Missing APPLE_APP_SPECIFIC_PASSWORD}"
: "${APPLE_NOTARY_TEAM_ID:?Missing APPLE_NOTARY_TEAM_ID}"

DMG_PATH="${DMG_PATH:?Missing DMG_PATH}"
APP_PATH="${APP_PATH:?Missing APP_PATH}"

xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$APPLE_NOTARY_TEAM_ID" \
  --wait

xcrun stapler staple "$APP_PATH"
xcrun stapler staple "$DMG_PATH"

