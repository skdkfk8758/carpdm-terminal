#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_SCRIPT="$ROOT_DIR/scripts/dev/install_local_app.sh"
CONFIGURATION="Debug"
INTERVAL_SECONDS="2"
DESTINATION=""
RESTART_APP=1
INITIAL_BUILD=1
APP_NAME="CarpdmTerminal"
WATCH_PATHS=(
  "Sources"
  "Config"
  "project.yml"
  "Package.swift"
  "Package.resolved"
)

print_usage() {
  cat <<'EOF'
Usage: scripts/dev/watch_local_app.sh [options]

Options:
  --dest <path>             Install destination. Defaults to /Applications if writable,
                            otherwise ~/Applications.
  --configuration <name>    Build configuration. Defaults to Debug.
  --interval <seconds>      Polling interval in seconds. Defaults to 2.
  --no-restart              Reinstall on changes but do not relaunch the app.
  --skip-initial-build      Start watching without the first build/install.
  --help                    Show this help.
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
    --interval)
      INTERVAL_SECONDS="${2:-}"
      shift 2
      ;;
    --no-restart)
      RESTART_APP=0
      shift
      ;;
    --skip-initial-build)
      INITIAL_BUILD=0
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
    DESTINATION="$HOME/Applications"
  fi
fi

TARGET_APP_PATH="$DESTINATION/$APP_NAME.app"

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

build_snapshot() {
  local files=()
  local relative_path=""

  for relative_path in "${WATCH_PATHS[@]}"; do
    local absolute_path="$ROOT_DIR/$relative_path"
    if [[ -f "$absolute_path" ]]; then
      files+=("$absolute_path")
    elif [[ -d "$absolute_path" ]]; then
      while IFS= read -r file; do
        files+=("$file")
      done < <(find "$absolute_path" -type f ! -name '.DS_Store' | sort)
    fi
  done

  if (( ${#files[@]} == 0 )); then
    printf 'empty'
    return
  fi

  {
    local file=""
    for file in "${files[@]}"; do
      stat -f '%m %N' "$file"
    done
  } | shasum -a 256 | awk '{print $1}'
}

restart_app() {
  if [[ "$RESTART_APP" -eq 0 ]]; then
    return
  fi

  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    log "Stopping running app..."
    osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || pkill -x "$APP_NAME" || true
    sleep 1
  fi

  if [[ -d "$TARGET_APP_PATH" ]]; then
    log "Opening $TARGET_APP_PATH"
    open "$TARGET_APP_PATH"
  fi
}

run_install() {
  local args=(--configuration "$CONFIGURATION" --dest "$DESTINATION" --no-open)

  log "Building and installing app..."
  if "$INSTALL_SCRIPT" "${args[@]}"; then
    restart_app
    log "Build/install complete."
  else
    log "Build/install failed. Watching for the next change."
  fi
}

trap 'log "Watcher stopped."; exit 0' INT TERM

log "Watching for changes in: ${WATCH_PATHS[*]}"
log "Install destination: $DESTINATION"
log "Polling interval: ${INTERVAL_SECONDS}s"

last_snapshot="$(build_snapshot)"

if [[ "$INITIAL_BUILD" -eq 1 ]]; then
  run_install
  last_snapshot="$(build_snapshot)"
fi

while true; do
  sleep "$INTERVAL_SECONDS"
  current_snapshot="$(build_snapshot)"
  if [[ "$current_snapshot" != "$last_snapshot" ]]; then
    log "Change detected."
    run_install
    last_snapshot="$(build_snapshot)"
  fi
done
