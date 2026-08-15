#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-relationship-runtime.XXXXXX")"
SMOKE_BIN="$SMOKE_ROOT/relationship-runtime-coordinator-smoke"
trap '/bin/rm -rf "$SMOKE_ROOT"' EXIT INT TERM

swift build --disable-sandbox >/dev/null
BUILD_BIN="$(swift build --disable-sandbox --show-bin-path)"
CONTRACT_OBJECTS=("$BUILD_BIN"/CompanionContracts.build/*.swift.o)

xcrun swiftc \
  -I "$BUILD_BIN/Modules" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionLocalization.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/Models.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionPresentationPreferences.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionFeedbackPresentation.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionInteractionPresentationAdapter.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionRelationshipRuntimeCoordinator.swift" \
  "$PROJECT_DIR/scripts/relationship-runtime-coordinator-smoke.swift" \
  "${CONTRACT_OBJECTS[@]}" \
  -o "$SMOKE_BIN"

"$SMOKE_BIN"
