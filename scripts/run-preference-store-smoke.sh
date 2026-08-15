#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
source "$PROJECT_DIR/scripts/swift-build-cache.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-preference-store.XXXXXX")"
SMOKE_BIN="$SMOKE_ROOT/preference-store-smoke"
BUILD_ROOT="$(chengyin_swift_build_root "$PROJECT_DIR" preference-store-smoke)"
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
  "$PROJECT_DIR/Sources/CompanionApp/CompanionPresentationPreferences.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionPreferenceStore.swift" \
  "$PROJECT_DIR/scripts/preference-store-smoke.swift" \
  "${CONTRACT_OBJECTS[@]}" \
  -o "$SMOKE_BIN"

"$SMOKE_BIN"
