#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-first-session.XXXXXX")"
trap 'rm -rf "$SMOKE_ROOT"' EXIT INT TERM

xcrun swiftc \
  -D COMPANION_STANDALONE_SMOKE \
  -parse-as-library \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionFirstSession.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionFirstSessionRuntimeCoordinator.swift" \
  "$PROJECT_DIR/scripts/first-session-runtime-coordinator-smoke.swift" \
  -o "$SMOKE_ROOT/first-session-runtime-smoke"

"$SMOKE_ROOT/first-session-runtime-smoke"
