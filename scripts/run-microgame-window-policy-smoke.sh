#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-microgame-window.XXXXXX")"
SMOKE_BIN="$SMOKE_ROOT/microgame-window-policy-smoke"
trap '/bin/rm -rf "$SMOKE_ROOT"' EXIT INT TERM

xcrun swiftc \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionSettings.swift" \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionPlayPaletteLayout.swift" \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionWindowPolicy.swift" \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionMicrogameWindowPolicy.swift" \
  "$PROJECT_DIR/scripts/microgame-window-policy-smoke.swift" \
  -o "$SMOKE_BIN"

"$SMOKE_BIN"
