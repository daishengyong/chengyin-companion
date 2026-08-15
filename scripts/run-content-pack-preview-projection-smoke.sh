#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
source "$repo_dir/scripts/swift-toolchain-env.sh"
smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-preview-projection.XXXXXX")"
smoke_bin="$smoke_root/content-pack-preview-projection-smoke"

cleanup() {
  rm -f "$smoke_bin"
  rmdir "$smoke_root" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

xcrun swiftc -D COMPANION_STANDALONE_SMOKE \
  "$repo_dir/Sources/CompanionContracts/CompanionSettings.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionPresentationProjection.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackManifest.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionFailureReceipt.swift" \
  "$repo_dir/Sources/CompanionApp/SemanticVersion.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackTriggerContract.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackManifestFieldValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackContributionValidationSupport.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackRightsValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackAccessibilityValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackFallbackValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackContributionValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackPackageContentsValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackAssetFileValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackAssetProjectionValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackAssetValidator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPack.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackProjectionPreview.swift" \
  "$repo_dir/scripts/content-pack-preview-projection-smoke.swift" \
  -o "$smoke_bin"

"$smoke_bin"
