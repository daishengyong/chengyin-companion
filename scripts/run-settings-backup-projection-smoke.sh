#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-settings-backup.XXXXXX")"
SMOKE_BIN="$SMOKE_ROOT/settings-backup-projection-smoke"
trap '/bin/rm -rf "$SMOKE_ROOT"' EXIT INT TERM

xcrun swiftc \
  -D COMPANION_STANDALONE_SMOKE \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionSettingsBackupProjection.swift" \
  "$PROJECT_DIR/scripts/settings-backup-projection-smoke.swift" \
  -o "$SMOKE_BIN"

"$SMOKE_BIN"
