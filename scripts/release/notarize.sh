#!/bin/zsh
set -euo pipefail

: "${APPLE_ID:?Missing APPLE_ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Missing APPLE_APP_SPECIFIC_PASSWORD}"
: "${APPLE_NOTARY_TEAM_ID:?Missing APPLE_NOTARY_TEAM_ID}"

APP_PATH="${APP_PATH:?Missing APP_PATH}"
ROOT_DIR="${ROOT_DIR:-$PWD}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
ZIP_PATH="${ZIP_PATH:-$DIST_DIR/CarpdmTerminal.zip}"
NOTARIZATION_ZIP_PATH="$(mktemp "${RUNNER_TEMP:-/tmp}/carpdm-notary.XXXXXX.zip")"

trap 'rm -f "$NOTARIZATION_ZIP_PATH"' EXIT

mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH"

/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$NOTARIZATION_ZIP_PATH"

xcrun notarytool submit "$NOTARIZATION_ZIP_PATH" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$APPLE_NOTARY_TEAM_ID" \
  --wait

xcrun stapler staple "$APP_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "ZIP_PATH=$ZIP_PATH" >> "$GITHUB_ENV"
