#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"

SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-runtime-repair.XXXXXX")"
SMOKE_BIN="$SMOKE_ROOT/runtime-repair-smoke"
cleanup() {
  rm -f "$SMOKE_BIN"
  rmdir "$SMOKE_ROOT" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

xcrun swiftc \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionEventBridgeRepair.swift" \
  "$PROJECT_DIR/scripts/runtime-repair-smoke.swift" \
  -o "$SMOKE_BIN"
"$SMOKE_BIN"
