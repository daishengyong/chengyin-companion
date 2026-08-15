#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"

SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-event-spool.XXXXXX")"
SMOKE_BIN="$SMOKE_ROOT/event-spool-smoke"
cleanup() {
  rm -f "$SMOKE_BIN"
  rmdir "$SMOKE_ROOT" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

xcrun swiftc \
  -D COMPANION_STANDALONE_SMOKE \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionEvent.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionEventSpool.swift" \
  "$PROJECT_DIR/scripts/event-spool-smoke.swift" \
  -o "$SMOKE_BIN"
"$SMOKE_BIN"
