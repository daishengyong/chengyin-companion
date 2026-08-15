#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
source "$PROJECT_DIR/scripts/swift-build-cache.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-pet-feedback.XXXXXX")"
SMOKE_BIN="$SMOKE_ROOT/pet-feedback-runtime-coordinator-smoke"
BUILD_ROOT="$(chengyin_swift_build_root "$PROJECT_DIR" pet-feedback-runtime-smoke)"
trap '/bin/rm -rf "$SMOKE_ROOT"' EXIT INT TERM

swift build \
  --disable-sandbox \
  --build-path "$BUILD_ROOT" \
  --target CompanionContracts \
  >/dev/null
BUILD_BIN="$(swift build --disable-sandbox --build-path "$BUILD_ROOT" --show-bin-path)"
CONTRACT_OBJECTS=("$BUILD_BIN"/CompanionContracts.build/*.swift.o)

xcrun swiftc \
  -I "$BUILD_BIN/Modules" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionLocalization.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/Models.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionPetFeedbackRuntimeCoordinator.swift" \
  "$PROJECT_DIR/scripts/pet-feedback-runtime-coordinator-smoke.swift" \
  "${CONTRACT_OBJECTS[@]}" \
  -o "$SMOKE_BIN"

"$SMOKE_BIN"
