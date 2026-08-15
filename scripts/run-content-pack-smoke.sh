#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
repo_dir="${script_dir:h}"
source "$repo_dir/scripts/swift-toolchain-env.sh"
smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-pack-smoke.XXXXXX")"
smoke_bin="$smoke_root/content-pack-smoke"

cleanup() {
  rm -f "$smoke_bin"
  rmdir "$smoke_root" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

xcrun swiftc -D COMPANION_STANDALONE_SMOKE -module-name ChengyinContentPackSmoke \
  "$repo_dir/Sources/CompanionContracts/CompanionSettings.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionPresentationProjection.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionBackup.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionEvent.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionWorkdayState.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionWorkDirector.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionLifestyleScheduler.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionLifestyleMemory.swift" \
  "$repo_dir/Sources/CompanionContracts/CompanionLocaleResolutionPolicy.swift" \
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
  "$repo_dir/Sources/CompanionApp/ContentPackVideoDecodeFallback.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackNonVideoMediaProbe.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackVideoMediaProbe.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackMediaProbe.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackMediaCheckpointDecoder.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackMediaQualityProbe.swift" \
  "$repo_dir/scripts/content-pack-creator-media-fallback.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackRecoveryCatalog.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreModels.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreDurability.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreLayout.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackActiveRecordRepository.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreLockCoordinator.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreRepository.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackInstallPreflight.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackInstallTransactions.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackRecoveryTransactions.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackPlaybackHealthTransactions.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreSnapshotProjection.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStoreMaintenanceTransactions.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackStore.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackArchivePolicy.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackArchiveImporter.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackRuntimeAccessibility.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackPlaybackModels.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackRuntimeCatalog.swift" \
  "$repo_dir/Sources/CompanionApp/ContentPackRuntimeSelection.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionContentSequenceRuntimeCoordinator.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionLocalization.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionLifestyleMemoryAdapter.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionWorkdayAdapter.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionErrorPresentation.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionSettingsPresentationModels.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionBackupService.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionContentLibraryModels.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionContentLibrary.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionContentOperationModels.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionContentOperationReceiptFactory.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionBackupOperationsCoordinator.swift" \
  "$repo_dir/Sources/CompanionApp/CompanionContentOperationsCoordinator.swift" \
  "$repo_dir/scripts/content-pack-smoke.swift" \
  -o "$smoke_bin"

"$smoke_bin"
