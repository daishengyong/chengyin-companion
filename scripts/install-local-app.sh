#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_NAME="Chengyin Companion"
SOURCE_APP="$PROJECT_DIR/dist/$APP_NAME.app"
TARGET_APP="/Applications/$APP_NAME.app"
BACKUP_DIR="$PROJECT_DIR/dist/install-backups"
COMMON_SCRIPT="$PROJECT_DIR/scripts/app-bundle-common.sh"
SWAP_SOURCE="$PROJECT_DIR/scripts/atomic-app-swap.swift"
WINDOW_AUDIT_SOURCE="$PROJECT_DIR/scripts/window-presence-audit.swift"
BUNDLE_ID="local.zidong.chengyin-companion"
PROCESS_NAME="ChengyinCompanion"
DRY_RUN=0
SKIP_BUILD=0

usage() {
  cat <<'USAGE'
Usage: ./scripts/install-local-app.sh [--dry-run] [--skip-build]

  --dry-run     Build and compare, but do not quit, replace or relaunch the app.
  --skip-build  Validate and install the existing dist app without rebuilding it.
USAGE
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
done

source "$COMMON_SCRIPT"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  "$PROJECT_DIR/scripts/build-app.sh"
fi

validate_app() {
  local app_path="$1"
  local require_event_helper="${2:-1}"
  local bundle_id

  if [[ ! -d "$app_path" ]]; then
    echo "Missing app bundle: $app_path" >&2
    return 1
  fi
  if [[ ! -x "$app_path/Contents/MacOS/$PROCESS_NAME" ]]; then
    echo "Missing executable in app bundle: $app_path" >&2
    return 1
  fi
  if [[ "$require_event_helper" -eq 1 \
    && ! -x "$app_path/Contents/SharedSupport/CompanionEventEmitter" ]]; then
    echo "Missing completion event helper in app bundle: $app_path" >&2
    return 1
  fi
  bundle_id="$(chengyin_plist_value "$app_path" CFBundleIdentifier || true)"
  if [[ "$bundle_id" != "$BUNDLE_ID" ]]; then
    echo "Unexpected bundle identifier in $app_path: $bundle_id" >&2
    return 1
  fi
  codesign --verify --deep --strict "$app_path"
}

validate_app "$SOURCE_APP"

CURRENT_SOURCE_FINGERPRINT="$(
  chengyin_source_fingerprint "$PROJECT_DIR"
)"
BUILT_SOURCE_FINGERPRINT="$(
  chengyin_plist_value "$SOURCE_APP" ChengyinSourceFingerprint || true
)"
if [[ -z "$BUILT_SOURCE_FINGERPRINT" ]]; then
  echo "The dist app has no build identity; rebuild without --skip-build." >&2
  exit 1
fi
if [[ "$BUILT_SOURCE_FINGERPRINT" != "$CURRENT_SOURCE_FINGERPRINT" ]]; then
  echo "The dist app is stale relative to the current source." >&2
  echo "Run without --skip-build to create a current app bundle." >&2
  exit 1
fi

SOURCE_BUNDLE_FINGERPRINT="$(chengyin_bundle_fingerprint "$SOURCE_APP")"
SOURCE_VERSION="$(chengyin_plist_value "$SOURCE_APP" CFBundleShortVersionString)"
SOURCE_BUILD="$(chengyin_plist_value "$SOURCE_APP" CFBundleVersion)"
SOURCE_LABEL="$(chengyin_bundle_label "$SOURCE_APP")"

echo "Candidate: $SOURCE_LABEL"
echo "Candidate fingerprint: $(chengyin_short_fingerprint "$SOURCE_BUNDLE_FINGERPRINT")"

TARGET_EXISTS=0
TARGET_SOURCE_FINGERPRINT=""
TARGET_BUNDLE_FINGERPRINT=""
TARGET_BUILD=""
if [[ -d "$TARGET_APP" ]]; then
  TARGET_EXISTS=1
  # A pre-bridge installation is a valid rollback source even though it does
  # not yet carry the new helper. Every candidate and post-swap app must.
  validate_app "$TARGET_APP" 0
  TARGET_SOURCE_FINGERPRINT="$(
    chengyin_plist_value "$TARGET_APP" ChengyinSourceFingerprint || true
  )"
  TARGET_BUNDLE_FINGERPRINT="$(chengyin_bundle_fingerprint "$TARGET_APP")"
  TARGET_BUILD="$(chengyin_plist_value "$TARGET_APP" CFBundleVersion || true)"
  echo "Installed: $(chengyin_bundle_label "$TARGET_APP")"
  echo "Installed fingerprint: $(chengyin_short_fingerprint "$TARGET_BUNDLE_FINGERPRINT")"

  if [[ "$SOURCE_BUILD" == <-> && "$TARGET_BUILD" == <-> \
    && "$SOURCE_BUILD" -lt "$TARGET_BUILD" ]]; then
    echo "Refusing to downgrade build $TARGET_BUILD to $SOURCE_BUILD." >&2
    exit 1
  fi
else
  echo "Installed: none"
fi

ALREADY_CURRENT=0
if [[ "$TARGET_EXISTS" -eq 1 \
  && "$TARGET_SOURCE_FINGERPRINT" == "$CURRENT_SOURCE_FINGERPRINT" ]] \
  && chengyin_apps_have_same_build_identity "$SOURCE_APP" "$TARGET_APP"; then
  ALREADY_CURRENT=1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ "$ALREADY_CURRENT" -eq 1 ]]; then
    echo "Dry run: the installed app already matches the candidate."
  else
    echo "Dry run: would quit $APP_NAME, atomically replace it, preserve"
    echo "preferences/content packs, retain the previous app as a backup,"
    echo "then relaunch and verify build $SOURCE_BUILD."
  fi
  exit 0
fi

if [[ "$ALREADY_CURRENT" -eq 1 ]]; then
  echo "$APP_NAME is already current; no files were replaced."
  if ! pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
    open -n "$TARGET_APP"
    echo "Relaunched $APP_NAME."
  fi
  exit 0
fi

if pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" \
    >/dev/null 2>&1 &
  QUIT_REQUEST_PID=$!
  for _ in {1..30}; do
    kill -0 "$QUIT_REQUEST_PID" >/dev/null 2>&1 || break
    sleep 0.1
  done
  if kill -0 "$QUIT_REQUEST_PID" >/dev/null 2>&1; then
    kill "$QUIT_REQUEST_PID" >/dev/null 2>&1 || true
  fi
  wait "$QUIT_REQUEST_PID" >/dev/null 2>&1 || true
  for _ in {1..50}; do
    pgrep -x "$PROCESS_NAME" >/dev/null 2>&1 || break
    sleep 0.1
  done
fi

if pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
  echo "The app did not answer the normal quit request; sending TERM to the exact Chengyin process." >&2
  while IFS= read -r app_pid; do
    if [[ "$app_pid" == <-> ]]; then
      kill -TERM "$app_pid" >/dev/null 2>&1 || true
    fi
  done < <(pgrep -x "$PROCESS_NAME")
  for _ in {1..50}; do
    pgrep -x "$PROCESS_NAME" >/dev/null 2>&1 || break
    sleep 0.1
  done
fi

if pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
  echo "Chengyin Companion is still running after bounded termination; installation stopped safely before replacement." >&2
  exit 1
fi

STATE_FINGERPRINT_BEFORE="$(chengyin_user_state_fingerprint "$HOME")"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_APP="$BACKUP_DIR/$APP_NAME-$STAMP-$$.app"
TARGET_PARENT="${TARGET_APP:h}"
STAGING_DIR="$(mktemp -d "$TARGET_PARENT/.chengyin-install.XXXXXX")"
STAGED_APP="$STAGING_DIR/$APP_NAME.app"
SWAP_HELPER="$STAGING_DIR/atomic-app-swap"
WINDOW_AUDIT_BIN="$STAGING_DIR/chengyin-window-audit"
KEEP_STAGING=0

cleanup() {
  if [[ "$KEEP_STAGING" -eq 0 \
    && -n "${STAGING_DIR:-}" \
    && "$STAGING_DIR" == "$TARGET_PARENT"/.chengyin-install.* \
    && -d "$STAGING_DIR" ]]; then
    /bin/rm -rf "$STAGING_DIR"
  fi
}
trap cleanup EXIT

ditto "$SOURCE_APP" "$STAGED_APP"
validate_app "$STAGED_APP"
if [[ "$(chengyin_bundle_fingerprint "$STAGED_APP")" != "$SOURCE_BUNDLE_FINGERPRINT" ]]; then
  echo "Staged app does not match the validated candidate." >&2
  exit 1
fi

xcrun swiftc "$SWAP_SOURCE" -o "$SWAP_HELPER"
xcrun swiftc "$WINDOW_AUDIT_SOURCE" -o "$WINDOW_AUDIT_BIN"
mkdir -p "$BACKUP_DIR"

if [[ "$TARGET_EXISTS" -eq 1 ]]; then
  "$SWAP_HELPER" "$STAGED_APP" "$TARGET_APP"
  if ! validate_app "$TARGET_APP" \
    || [[ "$(chengyin_bundle_fingerprint "$TARGET_APP")" \
      != "$SOURCE_BUNDLE_FINGERPRINT" ]]; then
    "$SWAP_HELPER" "$STAGED_APP" "$TARGET_APP" || true
    echo "Installed app verification failed; the previous app was restored." >&2
    exit 1
  fi
else
  mv "$STAGED_APP" "$TARGET_APP"
  if ! validate_app "$TARGET_APP" \
    || [[ "$(chengyin_bundle_fingerprint "$TARGET_APP")" \
      != "$SOURCE_BUNDLE_FINGERPRINT" ]]; then
    mv "$TARGET_APP" "$STAGED_APP" || true
    echo "New installation verification failed; no app was installed." >&2
    exit 1
  fi
fi

STATE_FINGERPRINT_AFTER="$(chengyin_user_state_fingerprint "$HOME")"
if [[ "$STATE_FINGERPRINT_BEFORE" != "$STATE_FINGERPRINT_AFTER" ]]; then
  if [[ "$TARGET_EXISTS" -eq 1 ]]; then
    "$SWAP_HELPER" "$STAGED_APP" "$TARGET_APP" || true
  else
    mv "$TARGET_APP" "$STAGED_APP" || true
  fi
  echo "User state changed during maintenance; the app update was rolled back." >&2
  exit 1
fi

open -n "$TARGET_APP" || true
for _ in {1..50}; do
  pgrep -x "$PROCESS_NAME" >/dev/null 2>&1 && break
  sleep 0.1
done
sleep 0.5
WINDOW_VISIBLE=0
for _ in {1..50}; do
  if "$WINDOW_AUDIT_BIN" >/dev/null 2>&1; then
    WINDOW_VISIBLE=1
    break
  fi
  sleep 0.1
done
if ! pgrep -x "$PROCESS_NAME" >/dev/null 2>&1 \
  || [[ "$WINDOW_VISIBLE" -ne 1 ]]; then
  while IFS= read -r app_pid; do
    if [[ "$app_pid" == <-> ]]; then
      kill -TERM "$app_pid" >/dev/null 2>&1 || true
    fi
  done < <(pgrep -x "$PROCESS_NAME" 2>/dev/null || true)
  for _ in {1..30}; do
    pgrep -x "$PROCESS_NAME" >/dev/null 2>&1 || break
    sleep 0.1
  done
  if [[ "$TARGET_EXISTS" -eq 1 ]]; then
    "$SWAP_HELPER" "$STAGED_APP" "$TARGET_APP" || true
    open -n "$TARGET_APP" >/dev/null 2>&1 || true
    echo "The new app did not keep a visible companion window; the previous app was restored." >&2
  else
    mv "$TARGET_APP" "$STAGED_APP" || true
    echo "The new app did not keep a visible companion window; no app was left installed." >&2
  fi
  exit 1
fi

if [[ "$TARGET_EXISTS" -eq 1 ]]; then
  if ! mv "$STAGED_APP" "$BACKUP_APP"; then
    KEEP_STAGING=1
    echo "The new app is installed, but the previous app remains at:" >&2
    echo "$STAGED_APP" >&2
  fi
fi

echo "Installed $APP_NAME $SOURCE_VERSION ($SOURCE_BUILD)"
echo "Build identity: $(chengyin_plist_value "$TARGET_APP" ChengyinBuildIdentity)"
echo "User preferences and content packs were unchanged."
if [[ -d "$BACKUP_APP" ]]; then
  echo "Previous app backup: $BACKUP_APP"
fi
