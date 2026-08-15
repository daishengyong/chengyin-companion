#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-voice-selection.XXXXXX")"
SMOKE_BIN="$SMOKE_ROOT/voice-selection-runtime-smoke"
trap '/bin/rm -rf "$SMOKE_ROOT"' EXIT INT TERM

xcrun swiftc \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionVoiceSelectionRuntimeCoordinator.swift" \
  "$PROJECT_DIR/scripts/voice-selection-runtime-smoke.swift" \
  -o "$SMOKE_BIN"

"$SMOKE_BIN"
