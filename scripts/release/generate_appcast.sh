#!/bin/zsh
set -euo pipefail

: "${SPARKLE_PRIVATE_KEY:?Missing SPARKLE_PRIVATE_KEY}"

ROOT_DIR="${ROOT_DIR:-$PWD}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DerivedData}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
UPDATES_DIR="${UPDATES_DIR:-$DIST_DIR/updates}"
DMG_PATH="${DMG_PATH:-$DIST_DIR/CarpdmTerminal.dmg}"
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-}"

if [[ -z "$SPARKLE_BIN_DIR" ]]; then
  GENERATOR="$(find "$DERIVED_DATA_PATH" -path '*/Sparkle/bin/generate_appcast' -print -quit 2>/dev/null || true)"
else
  GENERATOR="$SPARKLE_BIN_DIR/generate_appcast"
fi

test -x "$GENERATOR" || {
  echo "Sparkle generate_appcast not found at $GENERATOR"
  exit 1
}

mkdir -p "$UPDATES_DIR"
cp "$DMG_PATH" "$UPDATES_DIR/"

PRIVATE_KEY_PATH="$(mktemp "${RUNNER_TEMP:-/tmp}/sparkle-private-key.XXXXXX")"
trap 'rm -f "$PRIVATE_KEY_PATH"' EXIT
printf '%s' "$SPARKLE_PRIVATE_KEY" > "$PRIVATE_KEY_PATH"
chmod 600 "$PRIVATE_KEY_PATH"

"$GENERATOR" \
  --ed-key-file "$PRIVATE_KEY_PATH" \
  --download-url-prefix "${SPARKLE_DOWNLOAD_BASE_URL:-https://updates.example.com/carpdmterminal}" \
  "$UPDATES_DIR"

echo "APPCAST_PATH=$UPDATES_DIR/appcast.xml" >> "$GITHUB_ENV"
