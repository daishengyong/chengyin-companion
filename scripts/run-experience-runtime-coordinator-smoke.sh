#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-experience-runtime.XXXXXX")"
trap 'rm -rf "$SMOKE_ROOT"' EXIT INT TERM

xcrun swiftc \
  -D COMPANION_STANDALONE_SMOKE \
  -parse-as-library \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionEvent.swift" \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionWorkdayState.swift" \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionWorkDirector.swift" \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionAttentionBudget.swift" \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionExperienceDirector.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionExperienceRuntimeCoordinator.swift" \
  "$PROJECT_DIR/scripts/experience-runtime-coordinator-smoke.swift" \
  -o "$SMOKE_ROOT/experience-runtime-smoke"

"$SMOKE_ROOT/experience-runtime-smoke"
