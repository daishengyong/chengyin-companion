#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
source "$PROJECT_DIR/scripts/swift-toolchain-env.sh"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-projection-editor-smoke.XXXXXX")"
SMOKE_BIN="$SMOKE_ROOT/content-pack-projection-editor-smoke"

cleanup() {
  if [[ -n "${SMOKE_ROOT:-}" \
    && "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-projection-editor-smoke.* \
    && -d "$SMOKE_ROOT" ]]; then
    /bin/rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

xcrun swiftc -D COMPANION_STANDALONE_SMOKE \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionSettings.swift" \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionPresentationProjection.swift" \
  "$PROJECT_DIR/Sources/CompanionContracts/CompanionProjectionAuthoring.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackManifest.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/CompanionFailureReceipt.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/SemanticVersion.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackTriggerContract.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackManifestFieldValidator.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackContributionValidationSupport.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackRightsValidator.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackAccessibilityValidator.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackFallbackValidator.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackContributionValidator.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackPackageContentsValidator.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackAssetFileValidator.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackAssetProjectionValidator.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackAssetValidator.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPack.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackProjectionPreview.swift" \
  "$PROJECT_DIR/Sources/CompanionApp/ContentPackProjectionEditor.swift" \
  "$PROJECT_DIR/scripts/content-pack-projection-editor-smoke.swift" \
  -o "$SMOKE_BIN"

"$SMOKE_BIN"
