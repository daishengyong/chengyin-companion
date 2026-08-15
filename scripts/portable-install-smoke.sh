#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
ARCHIVE="$(find "$PROJECT_DIR/release" -maxdepth 1 -type f \
  -name 'Chengyin-Companion-*-macos-arm64-preview.zip' \
  -print0 \
  | xargs -0 stat -f '%m %N' \
  | sort -n \
  | tail -1 \
  | cut -d' ' -f2-)"
if [[ -z "$ARCHIVE" ]]; then
  echo "No portable preview archive found. Run make-portable-release.sh first." >&2
  exit 1
fi
SLUG="${ARCHIVE:t:r}"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-portable-smoke.XXXXXX")"
UNPACK_ROOT="$SMOKE_ROOT/unpacked"
FAKE_HOME="$SMOKE_ROOT/home"
INSTALL_ROOT="$FAKE_HOME/Applications"
AGENTS_PATH="$FAKE_HOME/.codex/AGENTS.md"
SUPPORT_ROOT="$FAKE_HOME/Library/Application Support/Chengyin"

mkdir -p "$UNPACK_ROOT" "$FAKE_HOME/.codex"
printf '# Existing user instructions\n' > "$AGENTS_PATH"
ditto -x -k "$ARCHIVE" "$UNPACK_ROOT"
PACKAGE_ROOT="$UNPACK_ROOT/$SLUG"

HOME="$FAKE_HOME" \
CHENGYIN_INSTALL_ROOT="$INSTALL_ROOT" \
CHENGYIN_AGENTS_PATH="$AGENTS_PATH" \
CHENGYIN_SUPPORT_ROOT="$SUPPORT_ROOT" \
CHENGYIN_INSTALL_SKIP_LAUNCH=1 \
CHENGYIN_INSTALL_SKIP_PROCESS_CONTROL=1 \
  "$PACKAGE_ROOT/Install Chengyin Companion.command"

test -x "$INSTALL_ROOT/Chengyin Companion.app/Contents/MacOS/ChengyinCompanion"
test -x "$INSTALL_ROOT/Chengyin Companion.app/Contents/SharedSupport/CompanionEventEmitter"
grep -Fq '# Existing user instructions' "$AGENTS_PATH"
test "$(grep -Fc '<!-- CHENGYIN-COMPANION-BEGIN -->' "$AGENTS_PATH")" -eq 1

EVENT_ROOT="$SMOKE_ROOT/events"
CHENGYIN_EVENT_ROOT="$EVENT_ROOT" \
  "$INSTALL_ROOT/Chengyin Companion.app/Contents/SharedSupport/CompanionEventEmitter" \
  task.completed
test "$(find "$EVENT_ROOT" -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' ')" -eq 1

DIAGNOSE_OUTPUT="$(HOME="$FAKE_HOME" \
CHENGYIN_INSTALL_ROOT="$INSTALL_ROOT" \
CHENGYIN_AGENTS_PATH="$AGENTS_PATH" \
  "$PACKAGE_ROOT/Diagnose Chengyin Companion.command")"
printf '%s\n' "$DIAGNOSE_OUTPUT"
printf '%s\n' "$DIAGNOSE_OUTPUT" \
  | grep -Fq '提示  应用当前未运行，可从“应用程序”中打开。'

printf 'Portable install smoke: PASS\n'
printf 'Isolated evidence: %s\n' "$SMOKE_ROOT"
