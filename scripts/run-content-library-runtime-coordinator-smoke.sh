#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-content-library-runtime.XXXXXX")"
SMOKE_BIN="$SMOKE_ROOT/content-library-runtime-coordinator-smoke"
trap '/bin/rm -rf "$SMOKE_ROOT"' EXIT INT TERM

xcrun swiftc \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionLocalization.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionContentLibraryRuntimeCoordinator.swift" \
  "$PROJECT_DIR/scripts/content-library-runtime-coordinator-smoke.swift" \
  -o "$SMOKE_BIN"

"$SMOKE_BIN"
