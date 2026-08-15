#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
source "$PROJECT_DIR/scripts/swift-build-cache.sh"
BUILD_ROOT="$(chengyin_swift_build_root "$PROJECT_DIR" shared-day-runtime-smoke)"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-shared-day-runtime.XXXXXX")"
SMOKE_BIN="$SMOKE_ROOT/shared-day-runtime-coordinator-smoke"
trap 'rm -rf "$SMOKE_ROOT"' EXIT INT TERM

swift build --build-path "$BUILD_ROOT" --disable-sandbox >/dev/null
BUILD_BIN="$(swift build --build-path "$BUILD_ROOT" --disable-sandbox --show-bin-path)"
CONTRACT_OBJECTS=("$BUILD_BIN"/CompanionContracts.build/*.swift.o)

xcrun swiftc \
  -I "$BUILD_BIN/Modules" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionLocalization.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/Models.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionFailureReceipt.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionEventBridgeRepair.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionEventSpool.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionEventIngress.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionEventWatcher.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionWorkdayAdapter.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionWorkdayRuntimeCoordinator.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionLifestyleMemoryAdapter.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionLifestyleRuntimeCoordinator.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionLifestyleEventProjection.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionLifestylePresentation.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionSharedDayRuntimeCoordinator.swift" \
  "$PROJECT_DIR/scripts/shared-day-runtime-coordinator-smoke.swift" \
  "${CONTRACT_OBJECTS[@]}" \
  -o "$SMOKE_BIN"

"$SMOKE_BIN"
