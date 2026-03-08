#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SCHEME="CarpdmTerminal"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
PROJECT_PATH="$ROOT_DIR/CarpdmTerminal.xcodeproj"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/CarpdmTerminal.app"
DEFAULT_USER_APPS_DIR="$HOME/Applications"
DESTINATION=""
SHOULD_OPEN=1

print_usage() {
  cat <<'EOF'
Usage: scripts/dev/install_local_app.sh [options]

Options:
  --dest <path>           Install destination. Defaults to /Applications if writable,
                          otherwise ~/Applications.
  --configuration <name>  Build configuration. Defaults to Debug.
  --no-open               Do not open the app after install.
  --help                  Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest)
      DESTINATION="${2:-}"
      shift 2
      ;;
    --configuration)
      CONFIGURATION="${2:-}"
      shift 2
      ;;
    --no-open)
      SHOULD_OPEN=0
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

if [[ -z "$DESTINATION" ]]; then
  if [[ -w "/Applications" ]]; then
    DESTINATION="/Applications"
  else
    DESTINATION="$DEFAULT_USER_APPS_DIR"
  fi
fi

mkdir -p "$DESTINATION"

echo "Generating Xcode project..."
cd "$ROOT_DIR"
xcodegen generate --spec "$ROOT_DIR/project.yml"

echo "Building $SCHEME ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at $APP_PATH" >&2
  exit 1
fi

TARGET_APP_PATH="$DESTINATION/CarpdmTerminal.app"

echo "Installing to $TARGET_APP_PATH..."
rm -rf "$TARGET_APP_PATH"
/usr/bin/ditto "$APP_PATH" "$TARGET_APP_PATH"

echo "Installed: $TARGET_APP_PATH"

if [[ "$SHOULD_OPEN" -eq 1 ]]; then
  echo "Opening app..."
  open "$TARGET_APP_PATH"
fi
