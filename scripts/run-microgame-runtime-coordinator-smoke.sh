#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-microgame-runtime.XXXXXX")"
trap 'rm -rf "$SMOKE_ROOT"' EXIT INT TERM

xcrun swiftc \
  -D COMPANION_STANDALONE_SMOKE \
  -parse-as-library \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionSettings.swift" \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionMicrogameSession.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionMicrogameRuntimeCoordinator.swift" \
  "$PROJECT_DIR/scripts/microgame-runtime-coordinator-smoke.swift" \
  -o "$SMOKE_ROOT/microgame-runtime-smoke"

"$SMOKE_ROOT/microgame-runtime-smoke"
