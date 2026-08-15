#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"

AUDIT_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-window-audit.XXXXXX")"
AUDIT_BIN="$AUDIT_ROOT/chengyin-window-audit"
cleanup() {
  rm -f "$AUDIT_BIN"
  rmdir "$AUDIT_ROOT" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

xcrun swiftc \
  "$PROJECT_DIR/scripts/window-presence-audit.swift" \
  -o "$AUDIT_BIN"
"$AUDIT_BIN"
