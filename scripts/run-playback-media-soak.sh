#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"

SOAK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-playback-soak.XXXXXX")"
SOAK_BIN="$SOAK_ROOT/playback-media-soak"
cleanup() {
  rm -f "$SOAK_BIN"
  rmdir "$SOAK_ROOT" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

xcrun swiftc \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionPlaybackHealth.swift" \
  "$PROJECT_DIR/scripts/playback-media-soak.swift" \
  -o "$SOAK_BIN"

if (( $# == 0 )); then
  set -- \
    --media-root "$PROJECT_DIR/Sources/CompanionApp/Resources" \
    --duration-seconds 1800
fi

"$SOAK_BIN" "$@"
