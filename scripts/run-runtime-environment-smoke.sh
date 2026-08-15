#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-runtime-environment.XXXXXX")"
SMOKE_BIN="$SMOKE_ROOT/runtime-environment-smoke"
SMOKE_MAIN="$SMOKE_ROOT/main.swift"

cleanup() {
  if [[ -n "${SMOKE_ROOT:-}" \
    && "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-runtime-environment.* \
    && -d "$SMOKE_ROOT" ]]; then
    /bin/rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

cp "$PROJECT_DIR/scripts/runtime-environment-smoke.swift" "$SMOKE_MAIN"
xcrun swiftc \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionRuntimeEnvironment.swift" \
  "$SMOKE_MAIN" \
  -o "$SMOKE_BIN"
"$SMOKE_BIN"
