#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
AUDITOR="$PROJECT_DIR/scripts/audit-core-module-boundaries.py"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-core-boundary.XXXXXX")"
trap 'rm -rf "$SMOKE_ROOT"' EXIT INT TERM

fail() {
  print -u2 "FAIL  $1"
  exit 1
}

make_case() {
  local name="$1"
  local destination="$SMOKE_ROOT/$name"
  mkdir -p "$destination/Sources"
  cp "$PROJECT_DIR/Package.swift" "$destination/Package.swift"
  cp "$PROJECT_DIR/Info.plist" "$destination/Info.plist"
  mkdir -p "$destination/Schemas"
  cp "$PROJECT_DIR/Schemas/core-module-boundary-baseline-v1.json" \
    "$destination/Schemas/core-module-boundary-baseline-v1.json"
  cp -R "$PROJECT_DIR/Sources/CompanionContracts" "$destination/Sources/CompanionContracts"
  mkdir -p "$destination/Sources/CompanionApp"
  local app_source
  for app_source in \
    CompanionViewModel.swift \
    ContentView.swift \
    CompanionSettingsView.swift \
    ContentPack.swift \
    ContentPackManifest.swift \
    ContentPackManifestFieldValidator.swift \
    ContentPackContributionValidationSupport.swift \
    ContentPackRightsValidator.swift \
    ContentPackAccessibilityValidator.swift \
    ContentPackFallbackValidator.swift \
    ContentPackContributionValidator.swift \
    ContentPackPackageContentsValidator.swift \
    ContentPackAssetFileValidator.swift \
    ContentPackAssetProjectionValidator.swift \
    ContentPackAssetValidator.swift \
    CompanionFailureReceipt.swift \
    SemanticVersion.swift \
    CompanionEventSpool.swift \
    CompanionEventIngress.swift \
    CompanionEventWatcher.swift \
    CompanionPetInteractionSurface.swift \
    CompanionWorkdayPresentation.swift \
    CompanionWorkdayApplicationProjection.swift \
    CompanionEventPresentation.swift \
    CompanionEventTriggerRouting.swift \
    ContentPackTriggerContract.swift \
    ContentPackPlaybackModels.swift \
    ContentPackRuntimeCatalog.swift \
    ContentPackRuntimeSelection.swift \
    CompanionContentSequenceRuntimeCoordinator.swift \
    ContentPackRuntimeAccessibility.swift \
    CompanionMediaAccessibilityPresentation.swift \
    ContentPackArchivePolicy.swift \
    ContentPackArchiveImporter.swift \
    CompanionContentPackImportPanel.swift \
    ContentPackRecoveryCatalog.swift \
    CompanionContentPackRecoverySection.swift \
    CompanionContentLibraryModels.swift \
    CompanionContentLibrary.swift \
    CompanionMediaPresentation.swift \
    CompanionStatusOverlays.swift \
    CompanionGestureDiscoveryCoordinator.swift \
    CompanionPresentationRuntimeCoordinator.swift \
    CompanionPetFeedbackRuntimeCoordinator.swift \
    CompanionContentLibraryRuntimeCoordinator.swift \
    CompanionPreferenceStore.swift \
    CompanionSettingsBackupProjection.swift \
    CompanionVoiceSelectionRuntimeCoordinator.swift \
    CompanionLifestyleRuntimeCoordinator.swift \
    CompanionLifestyleEventProjection.swift \
    CompanionLifestylePresentation.swift \
    CompanionContentOperationModels.swift \
    CompanionContentOperationReceiptFactory.swift \
    CompanionBackupOperationsCoordinator.swift \
    CompanionContentOperationsCoordinator.swift \
    CompanionRuntimeSupport.swift \
    CompanionRuntimeRepairCoordinator.swift \
    CompanionRuntimeReadinessPresentation.swift \
    CompanionMicrogamePresentation.swift \
    CompanionMicrogameCompletionPresentation.swift \
    CompanionTaskCompletionPresentation.swift \
    CompanionPetDragPresentation.swift \
    CompanionMicrogameRuntimeCoordinator.swift \
    CompanionExperienceRuntimeCoordinator.swift \
    CompanionWorkdayRuntimeCoordinator.swift \
    CompanionSharedDayRuntimeCoordinator.swift \
    CompanionFirstSessionRuntimeCoordinator.swift \
    CompanionFirstSessionCoach.swift \
    CompanionRelationshipRuntimeCoordinator.swift \
    CompanionRelationshipContentSelection.swift \
    ContentPackVideoDecodeFallback.swift \
    ContentPackMediaProbe.swift \
    ContentPackVideoMediaProbe.swift \
    ContentPackNonVideoMediaProbe.swift \
    ContentPackMediaCheckpointDecoder.swift \
    ContentPackMediaQualityProbe.swift \
    ContentPackStore.swift \
    ContentPackStoreLayout.swift \
    ContentPackActiveRecordRepository.swift \
    ContentPackStoreLockCoordinator.swift \
    ContentPackStoreRepository.swift \
    ContentPackInstallPreflight.swift \
    ContentPackInstallTransactions.swift \
    ContentPackRecoveryTransactions.swift \
    ContentPackPlaybackHealthTransactions.swift \
    ContentPackStoreSnapshotProjection.swift \
    ContentPackStoreMaintenanceTransactions.swift \
    ContentPackStoreModels.swift \
    ContentPackStoreDurability.swift; do
    cp "$PROJECT_DIR/Sources/CompanionApp/$app_source" \
      "$destination/Sources/CompanionApp/$app_source"
  done
  print -r -- "$destination"
}

expect_failure() {
  local expected_code="$1"
  local root="$2"
  local receipt
  local exit_status
  set +e
  receipt="$(python3 "$AUDITOR" --root "$root" --json)"
  exit_status=$?
  set -e
  [[ "$exit_status" -eq 1 ]] \
    || fail "expected $expected_code exit 1, received $exit_status"
  CORE_RECEIPT="$receipt" EXPECTED_CODE="$expected_code" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["CORE_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["code"] == os.environ["EXPECTED_CODE"], receipt
assert receipt["recoveryAction"], receipt
encoded = json.dumps(receipt)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
PY
}

baseline="$(make_case baseline)"
baseline_receipt="$(python3 "$AUDITOR" --root "$baseline" --json)"
CORE_RECEIPT="$baseline_receipt" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["CORE_RECEIPT"])
assert receipt["status"] == "PASS", receipt
assert receipt["coreModule"] == "CompanionContracts", receipt
assert receipt["appModule"] == "CompanionApp", receipt
assert receipt["requiredPolicyCount"] == 25, receipt
assert receipt["requiredPolicyLines"]["CompanionWorkdaySignalTrustPolicy.swift"] == 60, receipt
assert receipt["requiredPolicyLines"]["CompanionPlayPaletteLayout.swift"] == 89, receipt
assert receipt["requiredPolicyLines"]["CompanionLocaleResolutionPolicy.swift"] > 0, receipt
assert receipt["requiredPolicyLines"]["CompanionMicrogameWindowPolicy.swift"] == 218, receipt
assert receipt["networkRequired"] is False, receipt
assert receipt["compositionBudgetState"] == "WITHIN_BUDGET", receipt
for name, item in receipt["composition"].items():
    assert item["lines"] <= item["baselineLines"], (name, item)
    assert item["remainingLines"] == item["absoluteMaxLines"] - item["lines"], (name, item)
    assert item["deltaFromBaseline"] == item["lines"] - item["baselineLines"], (name, item)
    assert item["remainingPercent"] > 0, (name, item)
assert receipt["composition"]["CompanionViewModel.swift"]["baselineLines"] == 3576, receipt
assert receipt["composition"]["ContentView.swift"]["baselineLines"] == 1269, receipt
assert receipt["composition"]["CompanionSettingsView.swift"]["baselineLines"] == 525, receipt
assert receipt["composition"]["ContentPack.swift"]["baselineLines"] == 311, receipt
assert receipt["composition"]["ContentPack.swift"]["absoluteMaxLines"] == 420, receipt
assert receipt["composition"]["CompanionViewModel.swift"]["lines"] == 3576, receipt
assert receipt["composition"]["CompanionViewModel.swift"]["deltaFromBaseline"] == 0, receipt
assert all(
    item["deltaFromBaseline"] == 0
    for name, item in receipt["composition"].items()
), receipt
assert receipt["focusedAppModules"]["ContentPackManifest.swift"]["lines"] == 533, receipt
assert receipt["focusedAppModules"]["ContentPackManifestFieldValidator.swift"]["lines"] == 196, receipt
assert receipt["focusedAppModules"]["ContentPackManifestFieldValidator.swift"]["absoluteMaxLines"] == 240, receipt
assert receipt["focusedAppModules"]["ContentPackContributionValidationSupport.swift"]["lines"] == 133, receipt
assert receipt["focusedAppModules"]["ContentPackContributionValidationSupport.swift"]["absoluteMaxLines"] == 180, receipt
assert receipt["focusedAppModules"]["ContentPackRightsValidator.swift"]["lines"] == 174, receipt
assert receipt["focusedAppModules"]["ContentPackRightsValidator.swift"]["absoluteMaxLines"] == 240, receipt
assert receipt["focusedAppModules"]["ContentPackAccessibilityValidator.swift"]["lines"] == 168, receipt
assert receipt["focusedAppModules"]["ContentPackAccessibilityValidator.swift"]["absoluteMaxLines"] == 240, receipt
assert receipt["focusedAppModules"]["ContentPackFallbackValidator.swift"]["lines"] == 33, receipt
assert receipt["focusedAppModules"]["ContentPackFallbackValidator.swift"]["absoluteMaxLines"] == 80, receipt
assert receipt["focusedAppModules"]["ContentPackContributionValidator.swift"]["lines"] == 43, receipt
assert receipt["focusedAppModules"]["ContentPackContributionValidator.swift"]["absoluteMaxLines"] == 100, receipt
assert receipt["focusedAppModules"]["ContentPackPackageContentsValidator.swift"]["lines"] == 79, receipt
assert receipt["focusedAppModules"]["ContentPackPackageContentsValidator.swift"]["absoluteMaxLines"] == 140, receipt
assert receipt["focusedAppModules"]["ContentPackAssetFileValidator.swift"]["lines"] == 83, receipt
assert receipt["focusedAppModules"]["ContentPackAssetFileValidator.swift"]["absoluteMaxLines"] == 140, receipt
assert receipt["focusedAppModules"]["ContentPackAssetProjectionValidator.swift"]["lines"] == 155, receipt
assert receipt["focusedAppModules"]["ContentPackAssetProjectionValidator.swift"]["absoluteMaxLines"] == 220, receipt
assert receipt["focusedAppModules"]["ContentPackAssetValidator.swift"]["lines"] == 36, receipt
assert receipt["focusedAppModules"]["ContentPackAssetValidator.swift"]["absoluteMaxLines"] == 80, receipt
assert receipt["focusedAppModules"]["CompanionFailureReceipt.swift"]["lines"] == 432, receipt
assert receipt["focusedAppModules"]["CompanionEventSpool.swift"]["lines"] == 382, receipt
assert receipt["focusedAppModules"]["CompanionEventIngress.swift"]["lines"] == 125, receipt
assert receipt["focusedAppModules"]["CompanionEventIngress.swift"]["absoluteMaxLines"] == 180, receipt
assert receipt["focusedAppModules"]["CompanionEventWatcher.swift"]["lines"] == 260, receipt
assert receipt["focusedAppModules"]["CompanionEventWatcher.swift"]["absoluteMaxLines"] == 300, receipt
assert receipt["focusedAppModules"]["CompanionWorkdayPresentation.swift"]["lines"] == 104, receipt
assert receipt["focusedAppModules"]["CompanionWorkdayApplicationProjection.swift"]["lines"] == 96, receipt
assert receipt["focusedAppModules"]["CompanionWorkdayApplicationProjection.swift"]["absoluteMaxLines"] == 140, receipt
assert receipt["focusedAppModules"]["CompanionEventPresentation.swift"]["lines"] == 58, receipt
assert receipt["focusedAppModules"]["CompanionEventTriggerRouting.swift"]["lines"] == 32, receipt
assert receipt["focusedAppModules"]["ContentPackTriggerContract.swift"]["lines"] == 36, receipt
assert receipt["focusedAppModules"]["ContentPackPlaybackModels.swift"]["lines"] == 160, receipt
assert receipt["focusedAppModules"]["ContentPackPlaybackModels.swift"]["absoluteMaxLines"] == 200, receipt
assert receipt["focusedAppModules"]["ContentPackRuntimeCatalog.swift"]["lines"] == 133, receipt
assert receipt["focusedAppModules"]["ContentPackRuntimeCatalog.swift"]["absoluteMaxLines"] == 180, receipt
assert receipt["focusedAppModules"]["ContentPackRuntimeSelection.swift"]["lines"] == 318, receipt
assert receipt["focusedAppModules"]["ContentPackRuntimeSelection.swift"]["absoluteMaxLines"] == 400, receipt
assert receipt["focusedAppModules"]["CompanionContentSequenceRuntimeCoordinator.swift"]["lines"] == 93, receipt
assert receipt["focusedAppModules"]["CompanionContentSequenceRuntimeCoordinator.swift"]["absoluteMaxLines"] == 140, receipt
assert receipt["focusedAppModules"]["ContentPackRuntimeAccessibility.swift"]["lines"] == 149, receipt
assert receipt["focusedAppModules"]["CompanionMediaAccessibilityPresentation.swift"]["lines"] == 58, receipt
assert receipt["focusedAppModules"]["ContentPackArchivePolicy.swift"]["lines"] == 421, receipt
assert receipt["focusedAppModules"]["ContentPackArchiveImporter.swift"]["lines"] == 297, receipt
assert receipt["focusedAppModules"]["CompanionContentPackImportPanel.swift"]["lines"] == 30, receipt
assert receipt["focusedAppModules"]["ContentPackRecoveryCatalog.swift"]["lines"] == 219, receipt
assert receipt["focusedAppModules"]["CompanionContentPackRecoverySection.swift"]["lines"] == 114, receipt
assert receipt["focusedAppModules"]["CompanionContentLibraryModels.swift"]["lines"] == 39, receipt
assert receipt["focusedAppModules"]["CompanionContentLibraryModels.swift"]["absoluteMaxLines"] == 100, receipt
assert receipt["focusedAppModules"]["CompanionContentLibrary.swift"]["lines"] == 153, receipt
assert receipt["focusedAppModules"]["CompanionContentLibrary.swift"]["absoluteMaxLines"] == 170, receipt
assert receipt["focusedAppModules"]["CompanionMediaPresentation.swift"]["lines"] == 477, receipt
assert receipt["focusedAppModules"]["CompanionStatusOverlays.swift"]["lines"] == 224, receipt
assert receipt["focusedAppModules"]["CompanionStatusOverlays.swift"]["absoluteMaxLines"] == 280, receipt
assert receipt["focusedAppModules"]["CompanionGestureDiscoveryCoordinator.swift"]["lines"] == 94, receipt
assert receipt["focusedAppModules"]["CompanionGestureDiscoveryCoordinator.swift"]["absoluteMaxLines"] == 140, receipt
assert receipt["focusedAppModules"]["CompanionPresentationRuntimeCoordinator.swift"]["lines"] == 75, receipt
assert receipt["focusedAppModules"]["CompanionPresentationRuntimeCoordinator.swift"]["absoluteMaxLines"] == 120, receipt
assert receipt["focusedAppModules"]["CompanionPetFeedbackRuntimeCoordinator.swift"]["lines"] == 143, receipt
assert receipt["focusedAppModules"]["CompanionPetFeedbackRuntimeCoordinator.swift"]["absoluteMaxLines"] == 180, receipt
assert receipt["focusedAppModules"]["CompanionContentLibraryRuntimeCoordinator.swift"]["lines"] == 244, receipt
assert receipt["focusedAppModules"]["CompanionContentLibraryRuntimeCoordinator.swift"]["absoluteMaxLines"] == 300, receipt
assert receipt["focusedAppModules"]["CompanionPreferenceStore.swift"]["lines"] == 372, receipt
assert receipt["focusedAppModules"]["CompanionPreferenceStore.swift"]["absoluteMaxLines"] == 420, receipt
assert receipt["focusedAppModules"]["CompanionSettingsBackupProjection.swift"]["lines"] == 203, receipt
assert receipt["focusedAppModules"]["CompanionSettingsBackupProjection.swift"]["absoluteMaxLines"] == 240, receipt
assert receipt["focusedAppModules"]["CompanionVoiceSelectionRuntimeCoordinator.swift"]["lines"] == 94, receipt
assert receipt["focusedAppModules"]["CompanionVoiceSelectionRuntimeCoordinator.swift"]["absoluteMaxLines"] == 140, receipt
assert receipt["focusedAppModules"]["CompanionLifestyleRuntimeCoordinator.swift"]["lines"] == 253, receipt
assert receipt["focusedAppModules"]["CompanionLifestyleEventProjection.swift"]["lines"] == 50, receipt
assert receipt["focusedAppModules"]["CompanionLifestyleEventProjection.swift"]["absoluteMaxLines"] == 100, receipt
assert receipt["focusedAppModules"]["CompanionLifestylePresentation.swift"]["lines"] == 151, receipt
assert receipt["focusedAppModules"]["CompanionLifestylePresentation.swift"]["absoluteMaxLines"] == 180, receipt
assert receipt["focusedAppModules"]["CompanionContentOperationModels.swift"]["lines"] == 59, receipt
assert receipt["focusedAppModules"]["CompanionContentOperationModels.swift"]["absoluteMaxLines"] == 100, receipt
assert receipt["focusedAppModules"]["CompanionContentOperationReceiptFactory.swift"]["lines"] == 82, receipt
assert receipt["focusedAppModules"]["CompanionContentOperationReceiptFactory.swift"]["absoluteMaxLines"] == 120, receipt
assert receipt["focusedAppModules"]["CompanionBackupOperationsCoordinator.swift"]["lines"] == 188, receipt
assert receipt["focusedAppModules"]["CompanionBackupOperationsCoordinator.swift"]["absoluteMaxLines"] == 220, receipt
assert receipt["focusedAppModules"]["CompanionContentOperationsCoordinator.swift"]["lines"] == 320, receipt
assert receipt["focusedAppModules"]["CompanionContentOperationsCoordinator.swift"]["absoluteMaxLines"] == 360, receipt
assert receipt["focusedAppModules"]["CompanionRuntimeSupport.swift"]["lines"] == 211, receipt
assert receipt["focusedAppModules"]["CompanionRuntimeSupport.swift"]["absoluteMaxLines"] == 260, receipt
assert receipt["focusedAppModules"]["CompanionRuntimeRepairCoordinator.swift"]["lines"] == 162, receipt
assert receipt["focusedAppModules"]["CompanionRuntimeRepairCoordinator.swift"]["absoluteMaxLines"] == 220, receipt
assert receipt["focusedAppModules"]["CompanionRuntimeReadinessPresentation.swift"]["lines"] == 34, receipt
assert receipt["focusedAppModules"]["CompanionRuntimeReadinessPresentation.swift"]["absoluteMaxLines"] == 100, receipt
assert receipt["focusedAppModules"]["CompanionMicrogamePresentation.swift"]["lines"] == 148, receipt
assert receipt["focusedAppModules"]["CompanionMicrogamePresentation.swift"]["absoluteMaxLines"] == 220, receipt
assert receipt["focusedAppModules"]["CompanionMicrogameCompletionPresentation.swift"]["lines"] == 170, receipt
assert receipt["focusedAppModules"]["CompanionMicrogameCompletionPresentation.swift"]["absoluteMaxLines"] == 260, receipt
assert receipt["focusedAppModules"]["CompanionTaskCompletionPresentation.swift"]["lines"] == 94, receipt
assert receipt["focusedAppModules"]["CompanionTaskCompletionPresentation.swift"]["absoluteMaxLines"] == 180, receipt
assert receipt["focusedAppModules"]["CompanionPetDragPresentation.swift"]["lines"] == 88, receipt
assert receipt["focusedAppModules"]["CompanionPetDragPresentation.swift"]["absoluteMaxLines"] == 140, receipt
assert receipt["focusedAppModules"]["CompanionMicrogameRuntimeCoordinator.swift"]["lines"] == 226, receipt
assert receipt["focusedAppModules"]["CompanionExperienceRuntimeCoordinator.swift"]["lines"] == 276, receipt
assert receipt["focusedAppModules"]["CompanionWorkdayRuntimeCoordinator.swift"]["lines"] == 249, receipt
assert receipt["focusedAppModules"]["CompanionSharedDayRuntimeCoordinator.swift"]["lines"] == 144, receipt
assert receipt["focusedAppModules"]["CompanionSharedDayRuntimeCoordinator.swift"]["absoluteMaxLines"] == 220, receipt
assert receipt["focusedAppModules"]["CompanionFirstSessionRuntimeCoordinator.swift"]["lines"] > 0, receipt
assert receipt["focusedAppModules"]["CompanionFirstSessionCoach.swift"]["lines"] > 0, receipt
assert receipt["focusedAppModules"]["CompanionRelationshipRuntimeCoordinator.swift"]["lines"] == 240, receipt
assert receipt["focusedAppModules"]["CompanionRelationshipRuntimeCoordinator.swift"]["absoluteMaxLines"] == 280, receipt
assert receipt["focusedAppModules"]["CompanionRelationshipContentSelection.swift"]["lines"] == 18, receipt
assert receipt["focusedAppModules"]["CompanionRelationshipContentSelection.swift"]["absoluteMaxLines"] == 80, receipt
assert receipt["focusedAppModules"]["ContentPackVideoDecodeFallback.swift"]["lines"] == 12, receipt
assert receipt["focusedAppModules"]["ContentPackVideoDecodeFallback.swift"]["absoluteMaxLines"] == 80, receipt
assert receipt["focusedAppModules"]["ContentPackMediaProbe.swift"]["lines"] == 147, receipt
assert receipt["focusedAppModules"]["ContentPackMediaProbe.swift"]["absoluteMaxLines"] == 180, receipt
assert receipt["focusedAppModules"]["ContentPackVideoMediaProbe.swift"]["lines"] == 172, receipt
assert receipt["focusedAppModules"]["ContentPackVideoMediaProbe.swift"]["absoluteMaxLines"] == 220, receipt
assert receipt["focusedAppModules"]["ContentPackNonVideoMediaProbe.swift"]["lines"] == 106, receipt
assert receipt["focusedAppModules"]["ContentPackNonVideoMediaProbe.swift"]["absoluteMaxLines"] == 160, receipt
assert receipt["focusedAppModules"]["ContentPackMediaCheckpointDecoder.swift"]["lines"] == 87, receipt
assert receipt["focusedAppModules"]["ContentPackMediaCheckpointDecoder.swift"]["absoluteMaxLines"] == 140, receipt
assert receipt["focusedAppModules"]["ContentPackMediaQualityProbe.swift"]["lines"] == 142, receipt
assert receipt["focusedAppModules"]["ContentPackMediaQualityProbe.swift"]["absoluteMaxLines"] == 180, receipt
assert receipt["focusedAppModules"]["ContentPackStore.swift"]["lines"] == 269, receipt
assert receipt["focusedAppModules"]["ContentPackStore.swift"]["absoluteMaxLines"] == 300, receipt
assert receipt["focusedAppModules"]["ContentPackStoreRepository.swift"]["lines"] == 95, receipt
assert receipt["focusedAppModules"]["ContentPackStoreRepository.swift"]["absoluteMaxLines"] == 120, receipt
assert receipt["focusedAppModules"]["ContentPackStoreLayout.swift"]["lines"] == 53, receipt
assert receipt["focusedAppModules"]["ContentPackStoreLayout.swift"]["absoluteMaxLines"] == 80, receipt
assert receipt["focusedAppModules"]["ContentPackActiveRecordRepository.swift"]["lines"] == 79, receipt
assert receipt["focusedAppModules"]["ContentPackActiveRecordRepository.swift"]["absoluteMaxLines"] == 110, receipt
assert receipt["focusedAppModules"]["ContentPackStoreLockCoordinator.swift"]["lines"] == 29, receipt
assert receipt["focusedAppModules"]["ContentPackStoreLockCoordinator.swift"]["absoluteMaxLines"] == 60, receipt
assert receipt["focusedAppModules"]["ContentPackInstallPreflight.swift"]["lines"] == 114, receipt
assert receipt["focusedAppModules"]["ContentPackInstallPreflight.swift"]["absoluteMaxLines"] == 140, receipt
assert receipt["focusedAppModules"]["ContentPackInstallTransactions.swift"]["lines"] == 135, receipt
assert receipt["focusedAppModules"]["ContentPackInstallTransactions.swift"]["absoluteMaxLines"] == 180, receipt
assert receipt["focusedAppModules"]["ContentPackRecoveryTransactions.swift"]["lines"] == 138, receipt
assert receipt["focusedAppModules"]["ContentPackRecoveryTransactions.swift"]["absoluteMaxLines"] == 180, receipt
assert receipt["focusedAppModules"]["ContentPackPlaybackHealthTransactions.swift"]["lines"] == 89, receipt
assert receipt["focusedAppModules"]["ContentPackPlaybackHealthTransactions.swift"]["absoluteMaxLines"] == 140, receipt
assert receipt["focusedAppModules"]["ContentPackStoreSnapshotProjection.swift"]["lines"] == 40, receipt
assert receipt["focusedAppModules"]["ContentPackStoreSnapshotProjection.swift"]["absoluteMaxLines"] == 120, receipt
assert receipt["focusedAppModules"]["ContentPackStoreMaintenanceTransactions.swift"]["lines"] == 78, receipt
assert receipt["focusedAppModules"]["ContentPackStoreMaintenanceTransactions.swift"]["absoluteMaxLines"] == 120, receipt
assert receipt["focusedAppModules"]["ContentPackStoreModels.swift"]["lines"] == 173, receipt
assert receipt["focusedAppModules"]["ContentPackStoreModels.swift"]["absoluteMaxLines"] == 220, receipt
assert receipt["focusedAppModules"]["ContentPackStoreDurability.swift"]["lines"] == 89, receipt
assert receipt["focusedAppModules"]["ContentPackStoreDurability.swift"]["absoluteMaxLines"] == 140, receipt
assert receipt["proofStrength"] == "source-regex-and-token-guard-not-compiler-ast", receipt
assert receipt["evaluatedPackageGraphContract"] == "chengyin.swiftpm-package-graph/v1-required-by-doctor-ci-and-source-package", receipt
assert receipt["compilerParserBoundaryContract"] == "chengyin.swift-compiler-boundaries/v1-required-by-doctor-ci-contributor-and-source-package", receipt
assert receipt["futureHardeningCandidates"] == [
    "SwiftSyntax semantic policy audit",
    "compiler typechecked dependency scan",
    "continued monotonic composition-budget reduction",
], receipt
assert receipt["requiredPolicyLines"]["CompanionChemistryInteractionDirector.swift"] > 0, receipt
assert receipt["requiredPolicyLines"]["CompanionMicrogameCompletionPolicy.swift"] == 191, receipt
assert receipt["requiredPolicyLines"]["CompanionMicrogameSession.swift"] == 257, receipt
assert receipt["requiredPolicyLines"]["CompanionTaskCompletionPolicy.swift"] == 140, receipt
assert receipt["requiredPolicyLines"]["CompanionPetDragPolicy.swift"] == 155, receipt
PY

grep -Fq '3576/5600' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '1269/3000' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '3576/5600' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '1269/3000' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '280-line review budget' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '280 行聚焦预算' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '140-line review budget' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '140 行聚焦预算' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '311/420' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '311/420' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq 'Contribution validation is split into a 100-line dispatcher' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '贡献验证被拆成 100 行分发器' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '`ContentPackManifestFieldValidator.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`ContentPackContributionValidationSupport.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`ContentPackRightsValidator.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`ContentPackAccessibilityValidator.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`ContentPackFallbackValidator.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`ContentPackContributionValidator.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`ContentPackPackageContentsValidator.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`ContentPackAssetFileValidator.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`ContentPackAssetProjectionValidator.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`ContentPackAssetValidator.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '80-line stable dispatcher' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '80 行稳定分发器' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '`Sources/CompanionApp/CompanionContentSequenceRuntimeCoordinator.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`Sources/CompanionApp/CompanionSettingsBackupProjection.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq 'content-sequence runtime has a 140-line review budget' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '内容序列运行协调器有 140 行聚焦预算' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq 'pet feedback runtime has a 180-line review budget' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '宠物反馈运行协调器有 180 行聚焦预算' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq 'content library runtime has a 300-line review budget' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '内容库运行协调器有 300 行聚焦预算' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq 'workday application projection has a separate 140-line review budget' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '工作日应用投影另有 140 行聚焦预算' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '220-line review budget' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '220 行聚焦预算' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq 'coordinator and read-only Settings projection have 260-, 220- and 100-line' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '260、220 与 100 行聚焦预算' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '200-, 180-' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '120-, 220- and 360-line review budgets' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '200、180 与 400' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '100、120、220 与 360' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '280- and 80-line review budgets' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '280 与 80 行聚焦预算' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq 'primitives have 300-, 120-, 80-, 110-, 60-, 140-, 180-, 180-, 140-, 120-' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '分别有 300、120、80、110、60、140、180、180、140、120、120、220 与 140 行聚焦预算' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '`ContentPackStoreLayout.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`ContentPackActiveRecordRepository.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`ContentPackStoreLockCoordinator.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq '`ContentPackInstallTransactions.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq 'have 180-, 220-, 160- and 180-line review budgets' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '分别有 180、220、160 与 180 行聚焦预算' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '`ContentPackVideoMediaProbe.swift`' "$PROJECT_DIR/docs/CONTRIBUTOR-ARCHITECTURE.md"
grep -Fq 'audit-swift-compiler-boundaries.py --json' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq 'audit-swift-compiler-boundaries.py --json' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq 'not a type-checked dependency graph' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq '不是经过类型检查的依赖图' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq 'pet-drag presentation projection has a separate 140-line budget' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq 'CompanionMicrogameWindowPolicy' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.md"
grep -Fq 'CompanionMicrogameWindowPolicy' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"
grep -Fq '拖拽展示投影另有 140 行聚焦预算' "$PROJECT_DIR/docs/CORE-MODULE-BOUNDARY.zh-Hans.md"

layer="$(make_case layer)"
cp "$layer/Sources/CompanionContracts/CompanionLifestyleScheduler.swift" \
  "$layer/Sources/CompanionApp/CompanionLifestyleScheduler.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$layer"

settings_merge="$(make_case settings-merge)"
python3 - "$settings_merge/Sources/CompanionApp/ContentView.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8") + "\nstruct SettingsView: View {}\n",
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$settings_merge"

media_merge="$(make_case media-merge)"
print -r -- '' 'struct CompanionActionView: View {}' \
  >> "$media_merge/Sources/CompanionApp/ContentView.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$media_merge"

lifestyle_runtime_merge="$(make_case lifestyle-runtime-merge)"
print -r -- '' 'private let lifestyleMemoryAdapter: CompanionLifestyleMemoryAdapter' \
  >> "$lifestyle_runtime_merge/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$lifestyle_runtime_merge"

content_operations_merge="$(make_case content-operations-merge)"
print -r -- '' 'private let contentLibrary: CompanionContentLibrary' \
  >> "$content_operations_merge/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_operations_merge"

content_operation_models_merge="$(make_case content-operation-models-merge)"
print -r -- '' 'struct CompanionContentOperationReceipt {}' \
  >> "$content_operation_models_merge/Sources/CompanionApp/CompanionContentOperationsCoordinator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_operation_models_merge"

playback_models_merge="$(make_case playback-models-merge)"
print -r -- '' 'struct CompanionVideoAsset {}' \
  >> "$playback_models_merge/Sources/CompanionApp/ContentPackRuntimeCatalog.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$playback_models_merge"

runtime_selection_merge="$(make_case runtime-selection-merge)"
print -r -- '' 'func selectVideo(' \
  >> "$runtime_selection_merge/Sources/CompanionApp/ContentPackRuntimeCatalog.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$runtime_selection_merge"

runtime_repair_merge="$(make_case runtime-repair-merge)"
print -r -- '' '@Published private(set) var runtimeRepairInProgress = false' \
  >> "$runtime_repair_merge/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$runtime_repair_merge"

runtime_repair_side_effect="$(make_case runtime-repair-side-effect)"
print -r -- '' 'let fixture = UserDefaults.standard' \
  >> "$runtime_repair_side_effect/Sources/CompanionApp/CompanionRuntimeRepairCoordinator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$runtime_repair_side_effect"

runtime_readiness_presentation_side_effect="$(make_case runtime-readiness-presentation-side-effect)"
print -r -- '' 'let fixture = Task {}' \
  >> "$runtime_readiness_presentation_side_effect/Sources/CompanionApp/CompanionRuntimeReadinessPresentation.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$runtime_readiness_presentation_side_effect"

backup_operations_merge="$(make_case backup-operations-merge)"
print -r -- '' 'let manifest = try await library.exportBackup(' \
  >> "$backup_operations_merge/Sources/CompanionApp/CompanionContentOperationsCoordinator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$backup_operations_merge"

receipt_factory_merge="$(make_case receipt-factory-merge)"
print -r -- '' 'enum CompanionContentOperationReceiptFactory {}' \
  >> "$receipt_factory_merge/Sources/CompanionApp/CompanionContentOperationsCoordinator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$receipt_factory_merge"

microgame_runtime_merge="$(make_case microgame-runtime-merge)"
print -r -- '' 'private var catchGameTask: Task<Void, Never>?' \
  >> "$microgame_runtime_merge/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$microgame_runtime_merge"

microgame_presentation_merge="$(make_case microgame-presentation-merge)"
print -r -- '' 'var activePetGameHUDText: String { "fixture" }' \
  >> "$microgame_presentation_merge/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$microgame_presentation_merge"

microgame_presentation_side_effect="$(make_case microgame-presentation-side-effect)"
print -r -- '' 'let fixture = UserDefaults.standard' \
  >> "$microgame_presentation_side_effect/Sources/CompanionApp/CompanionMicrogamePresentation.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$microgame_presentation_side_effect"

microgame_completion_merge="$(make_case microgame-completion-merge)"
print -r -- '' 'let fixture = "game.catch.won"' \
  >> "$microgame_completion_merge/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$microgame_completion_merge"

microgame_completion_presentation_side_effect="$(make_case microgame-completion-presentation-side-effect)"
print -r -- '' 'let fixture = UserDefaults.standard' \
  >> "$microgame_completion_presentation_side_effect/Sources/CompanionApp/CompanionMicrogameCompletionPresentation.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$microgame_completion_presentation_side_effect"

task_completion_merge="$(make_case task-completion-merge)"
print -r -- '' 'private func completionReplyAction() {}' \
  >> "$task_completion_merge/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$task_completion_merge"

task_completion_presentation_side_effect="$(make_case task-completion-presentation-side-effect)"
print -r -- '' 'let fixture = UserDefaults.standard' \
  >> "$task_completion_presentation_side_effect/Sources/CompanionApp/CompanionTaskCompletionPresentation.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$task_completion_presentation_side_effect"

pet_drag_merge="$(make_case pet-drag-merge)"
python3 - "$pet_drag_merge/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "        let dragPlan = CompanionPetDragPolicy.plan(",
    "        let cue = .petFling\n        let dragPlan = CompanionPetDragPolicy.plan(",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$pet_drag_merge"

pet_drag_presentation_side_effect="$(make_case pet-drag-presentation-side-effect)"
print -r -- '' 'let fixture = UserDefaults.standard' \
  >> "$pet_drag_presentation_side_effect/Sources/CompanionApp/CompanionPetDragPresentation.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$pet_drag_presentation_side_effect"

experience_runtime_merge="$(make_case experience-runtime-merge)"
print -r -- '' 'private var eventTask: Task<Void, Never>?' \
  >> "$experience_runtime_merge/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$experience_runtime_merge"

experience_runtime_grace="$(make_case experience-runtime-grace)"
python3 - "$experience_runtime_grace/Sources/CompanionApp/CompanionExperienceRuntimeCoordinator.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "func noteUserInitiated(",
    "func removedNoteUserInitiated(",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$experience_runtime_grace"

workday_runtime_merge="$(make_case workday-runtime-merge)"
print -r -- '' 'private var completionReplyTask: Task<Void, Never>?' \
  >> "$workday_runtime_merge/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$workday_runtime_merge"

workday_projection_missing="$(make_case workday-projection-missing)"
rm "$workday_projection_missing/Sources/CompanionApp/CompanionWorkdayApplicationProjection.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$workday_projection_missing"

workday_projection_remerged="$(make_case workday-projection-remerged)"
print -r -- '' 'let fixture = presentation.relationshipReward' \
  >> "$workday_projection_remerged/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$workday_projection_remerged"

workday_projection_capability="$(make_case workday-projection-capability)"
print -r -- '' 'let fixture = UserDefaults.standard' \
  >> "$workday_projection_capability/Sources/CompanionApp/CompanionWorkdayApplicationProjection.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$workday_projection_capability"

workday_projection_delegate_missing="$(make_case workday-projection-delegate-missing)"
python3 - "$workday_projection_delegate_missing/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "CompanionWorkdayApplicationProjection.project(",
        "LegacyWorkdayApplicationProjection.project(",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$workday_projection_delegate_missing"

shared_day_missing="$(make_case shared-day-missing)"
rm "$shared_day_missing/Sources/CompanionApp/CompanionSharedDayRuntimeCoordinator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$shared_day_missing"

shared_day_timer_merge="$(make_case shared-day-timer-merge)"
print -r -- '' 'private var reminderTask: Task<Void, Never>?' \
  >> "$shared_day_timer_merge/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$shared_day_timer_merge"

content_pack_merge="$(make_case content-pack-merge)"
print -r -- '' 'struct ContentPackManifest {}' \
  >> "$content_pack_merge/Sources/CompanionApp/ContentPack.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_merge"

content_pack_field_missing="$(make_case content-pack-field-missing)"
rm "$content_pack_field_missing/Sources/CompanionApp/ContentPackManifestFieldValidator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_pack_field_missing"

content_pack_contribution_remerge="$(make_case content-pack-contribution-remerge)"
print -r -- '' 'let fixture = ContentPackValidationError.strictRightsMetadataMissing("asset")' \
  >> "$content_pack_contribution_remerge/Sources/CompanionApp/ContentPack.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_contribution_remerge"

content_pack_asset_remerge="$(make_case content-pack-asset-remerge)"
print -r -- '' 'let fixture = FileManager.default.isExecutableFile(atPath: "asset")' \
  >> "$content_pack_asset_remerge/Sources/CompanionApp/ContentPack.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_asset_remerge"

content_pack_contribution_capability="$(make_case content-pack-contribution-capability)"
print -r -- '' 'let fixture = FileManager.default' \
  >> "$content_pack_contribution_capability/Sources/CompanionApp/ContentPackContributionValidator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_contribution_capability"

content_pack_contribution_support_missing="$(make_case content-pack-contribution-support-missing)"
rm "$content_pack_contribution_support_missing/Sources/CompanionApp/ContentPackContributionValidationSupport.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_pack_contribution_support_missing"

content_pack_rights_missing="$(make_case content-pack-rights-missing)"
rm "$content_pack_rights_missing/Sources/CompanionApp/ContentPackRightsValidator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_pack_rights_missing"

content_pack_accessibility_missing="$(make_case content-pack-accessibility-missing)"
rm "$content_pack_accessibility_missing/Sources/CompanionApp/ContentPackAccessibilityValidator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_pack_accessibility_missing"

content_pack_fallback_missing="$(make_case content-pack-fallback-missing)"
rm "$content_pack_fallback_missing/Sources/CompanionApp/ContentPackFallbackValidator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_pack_fallback_missing"

content_pack_rights_delegate_missing="$(make_case content-pack-rights-delegate-missing)"
python3 - "$content_pack_rights_delegate_missing/Sources/CompanionApp/ContentPackContributionValidator.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "try rightsValidator.validate(",
        "try legacyRightsValidator.validate(",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_pack_rights_delegate_missing"

content_pack_policy_remerged="$(make_case content-pack-policy-remerged)"
print -r -- '' 'let fixture = ContentPackValidationError.strictAccessibilityMetadataMissing("asset")' \
  >> "$content_pack_policy_remerged/Sources/CompanionApp/ContentPackContributionValidator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_policy_remerged"

content_pack_support_filesystem="$(make_case content-pack-support-filesystem)"
print -r -- '' 'let fixture = Data(contentsOf: URL(fileURLWithPath: "/tmp/fixture"))' \
  >> "$content_pack_support_filesystem/Sources/CompanionApp/ContentPackContributionValidationSupport.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_support_filesystem"

content_pack_rights_capability="$(make_case content-pack-rights-capability)"
print -r -- '' 'let fixture = URLSession.shared' \
  >> "$content_pack_rights_capability/Sources/CompanionApp/ContentPackRightsValidator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_rights_capability"

content_pack_asset_capability="$(make_case content-pack-asset-capability)"
print -r -- '' 'let fixture = URLSession.shared' \
  >> "$content_pack_asset_capability/Sources/CompanionApp/ContentPackAssetValidator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_asset_capability"

content_pack_package_contents_missing="$(make_case content-pack-package-contents-missing)"
rm "$content_pack_package_contents_missing/Sources/CompanionApp/ContentPackPackageContentsValidator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_pack_package_contents_missing"

content_pack_asset_file_missing="$(make_case content-pack-asset-file-missing)"
rm "$content_pack_asset_file_missing/Sources/CompanionApp/ContentPackAssetFileValidator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_pack_asset_file_missing"

content_pack_asset_projection_missing="$(make_case content-pack-asset-projection-missing)"
rm "$content_pack_asset_projection_missing/Sources/CompanionApp/ContentPackAssetProjectionValidator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_pack_asset_projection_missing"

content_pack_asset_delegate_missing="$(make_case content-pack-asset-delegate-missing)"
python3 - "$content_pack_asset_delegate_missing/Sources/CompanionApp/ContentPackAssetValidator.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "try assetFileValidator.validate(asset, packageRoot: packageRoot)",
        "try legacyAssetFileValidator.validate(asset, packageRoot: packageRoot)",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_pack_asset_delegate_missing"

content_pack_asset_dispatcher_remerge="$(make_case content-pack-asset-dispatcher-remerge)"
print -r -- '' 'let fixture = ContentPackValidationError.safeAreaNotVisible(asset: "asset", mode: "pet")' \
  >> "$content_pack_asset_dispatcher_remerge/Sources/CompanionApp/ContentPackAssetValidator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_asset_dispatcher_remerge"

content_pack_package_projection_remerge="$(make_case content-pack-package-projection-remerge)"
print -r -- '' 'let fixture = ContentPackValidationError.invalidFocalTrack(asset: "asset", mode: "pet")' \
  >> "$content_pack_package_projection_remerge/Sources/CompanionApp/ContentPackPackageContentsValidator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_package_projection_remerge"

content_pack_asset_file_package_remerge="$(make_case content-pack-asset-file-package-remerge)"
print -r -- '' 'let fixture = ContentPackValidator.maximumFileCount' \
  >> "$content_pack_asset_file_package_remerge/Sources/CompanionApp/ContentPackAssetFileValidator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_asset_file_package_remerge"

content_pack_projection_filesystem="$(make_case content-pack-projection-filesystem)"
print -r -- '' 'let fixture = FileManager.default' \
  >> "$content_pack_projection_filesystem/Sources/CompanionApp/ContentPackAssetProjectionValidator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_projection_filesystem"

content_pack_package_hash_remerge="$(make_case content-pack-package-hash-remerge)"
print -r -- '' 'let fixture = "ContentPackValidator.sha256("' \
  >> "$content_pack_package_hash_remerge/Sources/CompanionApp/ContentPackPackageContentsValidator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_pack_package_hash_remerge"

content_pack_delegate_missing="$(make_case content-pack-delegate-missing)"
python3 - "$content_pack_delegate_missing/Sources/CompanionApp/ContentPack.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "ContentPackManifestFieldValidator.validate(manifestData)",
        "LegacyManifestFieldValidator.validate(manifestData)",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_pack_delegate_missing"

store_layout_merge="$(make_case store-layout-merge)"
print -r -- '' 'private let root: URL' \
  >> "$store_layout_merge/Sources/CompanionApp/ContentPackStore.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_layout_merge"

store_repository_policy="$(make_case store-repository-policy)"
print -r -- '' 'func install(' \
  >> "$store_repository_policy/Sources/CompanionApp/ContentPackStoreRepository.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_repository_policy"

store_repository_missing="$(make_case store-repository-missing)"
rm "$store_repository_missing/Sources/CompanionApp/ContentPackStoreRepository.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_repository_missing"

store_layout_missing="$(make_case store-layout-missing)"
rm "$store_layout_missing/Sources/CompanionApp/ContentPackStoreLayout.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_layout_missing"

store_active_records_missing="$(make_case store-active-records-missing)"
rm "$store_active_records_missing/Sources/CompanionApp/ContentPackActiveRecordRepository.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_active_records_missing"

store_lock_coordinator_missing="$(make_case store-lock-coordinator-missing)"
rm "$store_lock_coordinator_missing/Sources/CompanionApp/ContentPackStoreLockCoordinator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_lock_coordinator_missing"

store_facade_delegation_missing="$(make_case store-facade-delegation-missing)"
python3 - "$store_facade_delegation_missing/Sources/CompanionApp/ContentPackStoreRepository.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "try layout.prepareStore()",
        "try legacyLayout.prepareStore()",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_facade_delegation_missing"

store_layout_owns_lock="$(make_case store-layout-owns-lock)"
print -r -- '' 'let fixture: ContentPackStoreFileLock?' \
  >> "$store_layout_owns_lock/Sources/CompanionApp/ContentPackStoreLayout.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_layout_owns_lock"

store_active_records_owns_layout="$(make_case store-active-records-owns-layout)"
print -r -- '' 'var packsRoot: URL' \
  >> "$store_active_records_owns_layout/Sources/CompanionApp/ContentPackActiveRecordRepository.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_active_records_owns_layout"

store_lock_owns_record="$(make_case store-lock-owns-record)"
print -r -- '' 'let fixture = JSONDecoder()' \
  >> "$store_lock_owns_record/Sources/CompanionApp/ContentPackStoreLockCoordinator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_lock_owns_record"

store_facade_remerge="$(make_case store-facade-remerge)"
print -r -- '' 'let fixture = JSONDecoder()' \
  >> "$store_facade_remerge/Sources/CompanionApp/ContentPackStoreRepository.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_facade_remerge"

store_direct_lock="$(make_case store-direct-lock)"
print -r -- '' 'let fixture = try repository.acquireStoreLock()' \
  >> "$store_direct_lock/Sources/CompanionApp/ContentPackStore.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_direct_lock"

store_preflight_remerge="$(make_case store-preflight-remerge)"
print -r -- '' 'private func authorize(' \
  >> "$store_preflight_remerge/Sources/CompanionApp/ContentPackStore.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_preflight_remerge"

store_preflight_mutation="$(make_case store-preflight-mutation)"
print -r -- '' 'func fixture() { moveItem() }' \
  >> "$store_preflight_mutation/Sources/CompanionApp/ContentPackInstallPreflight.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_preflight_mutation"

store_preflight_missing="$(make_case store-preflight-missing)"
rm "$store_preflight_missing/Sources/CompanionApp/ContentPackInstallPreflight.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_preflight_missing"

store_install_missing="$(make_case store-install-missing)"
rm "$store_install_missing/Sources/CompanionApp/ContentPackInstallTransactions.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_install_missing"

store_install_owns_lock="$(make_case store-install-owns-lock)"
print -r -- '' 'func fixture() { withStoreLock() }' \
  >> "$store_install_owns_lock/Sources/CompanionApp/ContentPackInstallTransactions.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_install_owns_lock"

store_install_remerge="$(make_case store-install-remerge)"
print -r -- '' 'let fixture = repository.fileManager.copyItem(' \
  >> "$store_install_remerge/Sources/CompanionApp/ContentPackStore.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_install_remerge"

store_install_second_owner="$(make_case store-install-second-owner)"
print -r -- '' 'let fixture = ContentPackInstallTransactions(' \
  >> "$store_install_second_owner/Sources/CompanionApp/ContentView.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_install_second_owner"

store_install_scope_missing="$(make_case store-install-scope-missing)"
python3 - "$store_install_scope_missing/Sources/CompanionApp/ContentPackInstallTransactions.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "lockedBy scope: ContentPackStoreLockScope",
        "lockedBy scope: Int",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_install_scope_missing"

store_install_capability="$(make_case store-install-capability)"
print -r -- '' 'let fixture = URLSession.shared' \
  >> "$store_install_capability/Sources/CompanionApp/ContentPackInstallTransactions.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_install_capability"

store_recovery_owns_lock="$(make_case store-recovery-owns-lock)"
print -r -- '' 'func fixture() { withStoreLock() }' \
  >> "$store_recovery_owns_lock/Sources/CompanionApp/ContentPackRecoveryTransactions.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_recovery_owns_lock"

store_recovery_missing="$(make_case store-recovery-missing)"
rm "$store_recovery_missing/Sources/CompanionApp/ContentPackRecoveryTransactions.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_recovery_missing"

store_scope_forgeable="$(make_case store-scope-forgeable)"
python3 - "$store_scope_forgeable/Sources/CompanionApp/ContentPackStoreLockCoordinator.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace("fileprivate init() {}", "init() {}", 1),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_scope_forgeable"

store_recovery_remerge="$(make_case store-recovery-remerge)"
print -r -- '' 'func fixture() { lstat() }' \
  >> "$store_recovery_remerge/Sources/CompanionApp/ContentPackStore.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_recovery_remerge"

store_recovery_second_owner="$(make_case store-recovery-second-owner)"
print -r -- '' 'let fixture = ContentPackRecoveryTransactions(' \
  >> "$store_recovery_second_owner/Sources/CompanionApp/ContentView.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_recovery_second_owner"

store_recovery_scope_missing="$(make_case store-recovery-scope-missing)"
python3 - "$store_recovery_scope_missing/Sources/CompanionApp/ContentPackRecoveryTransactions.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "lockedBy scope: ContentPackStoreLockScope",
        "lockedBy scope: Int",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_recovery_scope_missing"

store_health_owns_lock="$(make_case store-health-owns-lock)"
print -r -- '' 'func fixture() { withStoreLock() }' \
  >> "$store_health_owns_lock/Sources/CompanionApp/ContentPackPlaybackHealthTransactions.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_health_owns_lock"

store_health_missing="$(make_case store-health-missing)"
rm "$store_health_missing/Sources/CompanionApp/ContentPackPlaybackHealthTransactions.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_health_missing"

store_health_remerge="$(make_case store-health-remerge)"
print -r -- '' 'let fixture = ContentPackStoreError.activeVersionChanged(' \
  >> "$store_health_remerge/Sources/CompanionApp/ContentPackStore.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_health_remerge"

store_health_second_owner="$(make_case store-health-second-owner)"
print -r -- '' 'let fixture = ContentPackPlaybackHealthTransactions(' \
  >> "$store_health_second_owner/Sources/CompanionApp/ContentView.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_health_second_owner"

store_health_scope_missing="$(make_case store-health-scope-missing)"
python3 - "$store_health_scope_missing/Sources/CompanionApp/ContentPackPlaybackHealthTransactions.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "lockedBy scope: ContentPackStoreLockScope",
        "lockedBy scope: Int",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_health_scope_missing"

store_snapshot_owns_lock="$(make_case store-snapshot-owns-lock)"
print -r -- '' 'func fixture() { withStoreLock() }' \
  >> "$store_snapshot_owns_lock/Sources/CompanionApp/ContentPackStoreSnapshotProjection.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_snapshot_owns_lock"

store_snapshot_missing="$(make_case store-snapshot-missing)"
rm "$store_snapshot_missing/Sources/CompanionApp/ContentPackStoreSnapshotProjection.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_snapshot_missing"

store_snapshot_remerge="$(make_case store-snapshot-remerge)"
print -r -- '' 'let directories = try repository.fileManager.contentsOfDirectory(' \
  >> "$store_snapshot_remerge/Sources/CompanionApp/ContentPackStore.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_snapshot_remerge"

store_snapshot_second_owner="$(make_case store-snapshot-second-owner)"
print -r -- '' 'let fixture = ContentPackStoreSnapshotProjection(' \
  >> "$store_snapshot_second_owner/Sources/CompanionApp/ContentView.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_snapshot_second_owner"

store_snapshot_scope_missing="$(make_case store-snapshot-scope-missing)"
python3 - "$store_snapshot_scope_missing/Sources/CompanionApp/ContentPackStoreSnapshotProjection.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "lockedBy scope: ContentPackStoreLockScope",
        "lockedBy scope: Int",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_snapshot_scope_missing"

store_maintenance_owns_lock="$(make_case store-maintenance-owns-lock)"
print -r -- '' 'func fixture() { withStoreLock() }' \
  >> "$store_maintenance_owns_lock/Sources/CompanionApp/ContentPackStoreMaintenanceTransactions.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_maintenance_owns_lock"

store_maintenance_missing="$(make_case store-maintenance-missing)"
rm "$store_maintenance_missing/Sources/CompanionApp/ContentPackStoreMaintenanceTransactions.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_maintenance_missing"

store_maintenance_remerge="$(make_case store-maintenance-remerge)"
print -r -- '' 'let candidates = try repository.fileManager.contentsOfDirectory(' \
  >> "$store_maintenance_remerge/Sources/CompanionApp/ContentPackStore.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_maintenance_remerge"

store_maintenance_second_owner="$(make_case store-maintenance-second-owner)"
print -r -- '' 'let fixture = ContentPackStoreMaintenanceTransactions(' \
  >> "$store_maintenance_second_owner/Sources/CompanionApp/ContentView.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$store_maintenance_second_owner"

store_maintenance_scope_missing="$(make_case store-maintenance-scope-missing)"
python3 - "$store_maintenance_scope_missing/Sources/CompanionApp/ContentPackStoreMaintenanceTransactions.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "lockedBy scope: ContentPackStoreLockScope",
        "lockedBy scope: Int",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$store_maintenance_scope_missing"

content_library_split_snapshot="$(make_case content-library-split-snapshot)"
print -r -- '' 'let fixture = try await store.recoveryInventory()' \
  >> "$content_library_split_snapshot/Sources/CompanionApp/CompanionContentLibrary.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_library_split_snapshot"

content_library_models_missing="$(make_case content-library-models-missing)"
rm "$content_library_models_missing/Sources/CompanionApp/CompanionContentLibraryModels.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_library_models_missing"

focused_budget="$(make_case focused-budget)"
python3 - "$focused_budget/Sources/CompanionApp/SemanticVersion.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(p.read_text(encoding="utf-8") + ("// fixture growth\n" * 80), encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_FOCUSED_MODULE_BUDGET_EXCEEDED "$focused_budget"

event_focused_budget="$(make_case event-focused-budget)"
python3 - "$event_focused_budget/Sources/CompanionApp/CompanionEventWatcher.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(p.read_text(encoding="utf-8") + ("// fixture growth\n" * 60), encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_FOCUSED_MODULE_BUDGET_EXCEEDED "$event_focused_budget"

dependency="$(make_case dependency)"
python3 - "$dependency/Sources/CompanionContracts/CompanionWorkDirector.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text("import SwiftUI\n" + p.read_text(encoding="utf-8"), encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_FORBIDDEN_DEPENDENCY "$dependency"

surface="$(make_case surface)"
python3 - "$surface/Sources/CompanionContracts/CompanionLifestyleScheduler.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public enum CompanionLifestyleReminderKind",
    "enum CompanionLifestyleReminderKind",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$surface"

memory_surface="$(make_case memory-surface)"
python3 - "$memory_surface/Sources/CompanionContracts/CompanionLifestyleMemory.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public final class CompanionLifestyleMemoryStore",
    "final class CompanionLifestyleMemoryStore",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$memory_surface"

workday_surface="$(make_case workday-surface)"
python3 - "$workday_surface/Sources/CompanionContracts/CompanionWorkdayState.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public struct CompanionWorkdayStateLoadResult",
    "struct CompanionWorkdayStateLoadResult",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$workday_surface"

workday_experience_surface="$(make_case workday-experience-surface)"
python3 - "$workday_experience_surface/Sources/CompanionContracts/CompanionWorkdaySignalTrustPolicy.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public enum CompanionWorkdaySignalTrustPolicy",
    "enum CompanionWorkdaySignalTrustPolicy",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$workday_experience_surface"

chemistry_surface="$(make_case chemistry-surface)"
python3 - "$chemistry_surface/Sources/CompanionContracts/CompanionChemistryInteractionDirector.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public struct CompanionChemistryInteractionDirector",
    "struct CompanionChemistryInteractionDirector",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$chemistry_surface"

user_presentation_surface="$(make_case user-presentation-surface)"
python3 - "$user_presentation_surface/Sources/CompanionContracts/CompanionUserPresentationPolicy.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public struct CompanionUserPresentationPolicy",
    "struct CompanionUserPresentationPolicy",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$user_presentation_surface"

presentation_session_surface="$(make_case presentation-session-surface)"
python3 - "$presentation_session_surface/Sources/CompanionContracts/CompanionPresentationSession.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public struct CompanionPresentationSession",
    "struct CompanionPresentationSession",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$presentation_session_surface"

presentation_lifecycle_surface="$(make_case presentation-lifecycle-surface)"
python3 - "$presentation_lifecycle_surface/Sources/CompanionContracts/CompanionPresentationLifecycle.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public struct CompanionPresentationLifecycle",
    "struct CompanionPresentationLifecycle",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$presentation_lifecycle_surface"

play_palette_surface="$(make_case play-palette-surface)"
python3 - "$play_palette_surface/Sources/CompanionContracts/CompanionPlayPaletteLayout.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public enum CompanionPlayPaletteLayout",
    "enum CompanionPlayPaletteLayout",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$play_palette_surface"

playback_health_surface="$(make_case playback-health-surface)"
python3 - "$playback_health_surface/Sources/CompanionContracts/CompanionPlaybackHealth.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public struct CompanionPlaybackHealthAccumulator",
    "struct CompanionPlaybackHealthAccumulator",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$playback_health_surface"

runtime_readiness_surface="$(make_case runtime-readiness-surface)"
python3 - "$runtime_readiness_surface/Sources/CompanionContracts/CompanionRuntimeReadiness.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public static func safeRecoveryActions",
    "static func safeRecoveryActions",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$runtime_readiness_surface"

projection_surface="$(make_case projection-surface)"
python3 - "$projection_surface/Sources/CompanionContracts/CompanionPresentationProjection.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public struct CompanionMediaFocalTrack",
    "struct CompanionMediaFocalTrack",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$projection_surface"

authoring_surface="$(make_case authoring-surface)"
python3 - "$authoring_surface/Sources/CompanionContracts/CompanionProjectionAuthoring.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public struct CompanionProjectionAuthoringReceipt",
    "struct CompanionProjectionAuthoringReceipt",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$authoring_surface"

environment_surface="$(make_case environment-surface)"
python3 - "$environment_surface/Sources/CompanionContracts/CompanionPresentationEnvironment.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public enum CompanionDisplaySelectionPolicy",
    "enum CompanionDisplaySelectionPolicy",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$environment_surface"

microgame_surface="$(make_case microgame-surface)"
python3 - "$microgame_surface/Sources/CompanionContracts/CompanionMicrogameSession.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public struct CompanionMicrogameSession",
    "struct CompanionMicrogameSession",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$microgame_surface"

microgame_window_missing="$(make_case microgame-window-missing)"
rm "$microgame_window_missing/Sources/CompanionContracts/CompanionMicrogameWindowPolicy.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$microgame_window_missing"

microgame_window_surface="$(make_case microgame-window-surface)"
python3 - "$microgame_window_surface/Sources/CompanionContracts/CompanionMicrogameWindowPolicy.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public enum CompanionMicrogameWindowPolicy",
    "enum CompanionMicrogameWindowPolicy",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$microgame_window_surface"

microgame_window_capability="$(make_case microgame-window-capability)"
print -r -- 'import AppKit' \
  >> "$microgame_window_capability/Sources/CompanionContracts/CompanionMicrogameWindowPolicy.swift"
expect_failure CORE_BOUNDARY_FORBIDDEN_DEPENDENCY "$microgame_window_capability"

microgame_window_delegate_missing="$(make_case microgame-window-delegate-missing)"
python3 - "$microgame_window_delegate_missing/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "CompanionMicrogameWindowPolicy.catchPlacement(",
        "LegacyMicrogameWindowPolicy.catchPlacement(",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_POLICY_DELEGATION_MISSING "$microgame_window_delegate_missing"

microgame_window_remerged="$(make_case microgame-window-remerged)"
print -r -- 'let safeX = [' \
  >> "$microgame_window_remerged/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_POLICY_REMERGED "$microgame_window_remerged"

microgame_completion_surface="$(make_case microgame-completion-surface)"
python3 - "$microgame_completion_surface/Sources/CompanionContracts/CompanionMicrogameCompletionPolicy.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public struct CompanionMicrogameCompletionPolicy",
    "struct CompanionMicrogameCompletionPolicy",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$microgame_completion_surface"

task_completion_surface="$(make_case task-completion-surface)"
python3 - "$task_completion_surface/Sources/CompanionContracts/CompanionTaskCompletionPolicy.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public enum CompanionTaskCompletionPolicy",
    "enum CompanionTaskCompletionPolicy",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$task_completion_surface"

pet_drag_surface="$(make_case pet-drag-surface)"
python3 - "$pet_drag_surface/Sources/CompanionContracts/CompanionPetDragPolicy.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8").replace(
    "public enum CompanionPetDragPolicy",
    "enum CompanionPetDragPolicy",
    1,
)
p.write_text(text, encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PUBLIC_SURFACE_MISSING "$pet_drag_surface"

monotonic="$(make_case monotonic)"
python3 - "$monotonic/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8") + ("// fixture growth\n" * 32),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_MONOTONIC_BUDGET_EXCEEDED "$monotonic"

budget="$(make_case budget)"
python3 - "$budget/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1])
source.write_text(
    source.read_text(encoding="utf-8") + "\n" + ("// fixture growth\n" * 2025),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_COMPOSITION_BUDGET_EXCEEDED "$budget"

package_case="$(make_case package)"
python3 - "$package_case/Package.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(p.read_text(encoding="utf-8").replace(
    'dependencies: ["CompanionContracts"]',
    'dependencies: []',
    1,
), encoding="utf-8")
PY
expect_failure CORE_BOUNDARY_PACKAGE_DEPENDENCY_MISSING "$package_case"

media_quality_missing="$(make_case media-quality-missing)"
rm "$media_quality_missing/Sources/CompanionApp/ContentPackMediaQualityProbe.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$media_quality_missing"

media_non_video_missing="$(make_case media-non-video-missing)"
rm "$media_non_video_missing/Sources/CompanionApp/ContentPackNonVideoMediaProbe.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$media_non_video_missing"

media_non_video_remerged="$(make_case media-non-video-remerged)"
print -r -- 'let fixture = CGImageSourceCreateWithURL(url as CFURL, nil)' \
  >> "$media_non_video_remerged/Sources/CompanionApp/ContentPackMediaProbe.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$media_non_video_remerged"

media_non_video_capability="$(make_case media-non-video-capability)"
print -r -- 'let fixture = URLSession.shared' \
  >> "$media_non_video_capability/Sources/CompanionApp/ContentPackNonVideoMediaProbe.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$media_non_video_capability"

media_non_video_delegate_missing="$(make_case media-non-video-delegate-missing)"
python3 - "$media_non_video_delegate_missing/Sources/CompanionApp/ContentPackMediaProbe.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "nonVideoProbe.probeImage(",
        "LegacyNonVideoProbe.probeImage(",
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$media_non_video_delegate_missing"

media_video_missing="$(make_case media-video-missing)"
rm "$media_video_missing/Sources/CompanionApp/ContentPackVideoMediaProbe.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$media_video_missing"

media_video_remerged="$(make_case media-video-remerged)"
print -r -- 'let fixture = AVURLAsset(url: url)' \
  >> "$media_video_remerged/Sources/CompanionApp/ContentPackMediaProbe.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$media_video_remerged"

media_video_capability="$(make_case media-video-capability)"
print -r -- 'let fixture = URLSession.shared' \
  >> "$media_video_capability/Sources/CompanionApp/ContentPackVideoMediaProbe.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$media_video_capability"

media_video_delegate_missing="$(make_case media-video-delegate-missing)"
python3 - "$media_video_delegate_missing/Sources/CompanionApp/ContentPackMediaProbe.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "videoProbe.probeVideo(",
        "LegacyVideoProbe.probeVideo(",
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$media_video_delegate_missing"

media_video_second_owner="$(make_case media-video-second-owner)"
print -r -- '' 'let fixture = AVFoundationContentPackVideoMediaProbe(' \
  >> "$media_video_second_owner/Sources/CompanionApp/ContentView.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$media_video_second_owner"

media_fallback_missing="$(make_case media-fallback-missing)"
rm "$media_fallback_missing/Sources/CompanionApp/ContentPackVideoDecodeFallback.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$media_fallback_missing"

media_fallback_remerged="$(make_case media-fallback-remerged)"
print -r -- 'protocol ContentPackVideoDecodeFallback {}' \
  >> "$media_fallback_remerged/Sources/CompanionApp/ContentPackMediaProbe.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$media_fallback_remerged"

media_fallback_unrelated="$(make_case media-fallback-unrelated)"
print -r -- 'let fixture = URLSession.shared' \
  >> "$media_fallback_unrelated/Sources/CompanionApp/ContentPackVideoDecodeFallback.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$media_fallback_unrelated"

media_quality_remerged="$(make_case media-quality-remerged)"
print -r -- 'let fixture = AVAssetReader(asset: asset)' \
  >> "$media_quality_remerged/Sources/CompanionApp/ContentPackMediaProbe.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$media_quality_remerged"

media_quality_unrelated="$(make_case media-quality-unrelated)"
print -r -- 'let fixture = URLSession.shared' \
  >> "$media_quality_unrelated/Sources/CompanionApp/ContentPackMediaQualityProbe.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$media_quality_unrelated"

media_quality_delegate_missing="$(make_case media-quality-delegate-missing)"
python3 - "$media_quality_delegate_missing/Sources/CompanionApp/ContentPackVideoMediaProbe.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "ContentPackMediaQualityProbe().probe(",
        "LegacyMediaQualityProbe().probe(",
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$media_quality_delegate_missing"

media_checkpoint_missing="$(make_case media-checkpoint-missing)"
rm "$media_checkpoint_missing/Sources/CompanionApp/ContentPackMediaCheckpointDecoder.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$media_checkpoint_missing"

media_checkpoint_remerged="$(make_case media-checkpoint-remerged)"
print -r -- 'let fixture = AVAssetReader(asset: asset)' \
  >> "$media_checkpoint_remerged/Sources/CompanionApp/ContentPackMediaQualityProbe.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$media_checkpoint_remerged"

media_checkpoint_unrelated="$(make_case media-checkpoint-unrelated)"
print -r -- 'let fixture = URLSession.shared' \
  >> "$media_checkpoint_unrelated/Sources/CompanionApp/ContentPackMediaCheckpointDecoder.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$media_checkpoint_unrelated"

media_checkpoint_delegate_missing="$(make_case media-checkpoint-delegate-missing)"
python3 - "$media_checkpoint_delegate_missing/Sources/CompanionApp/ContentPackMediaQualityProbe.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "ContentPackMediaCheckpointDecoder()",
        "LegacyCheckpointDecoder()",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$media_checkpoint_delegate_missing"

status_overlays_missing="$(make_case status-overlays-missing)"
rm "$status_overlays_missing/Sources/CompanionApp/CompanionStatusOverlays.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$status_overlays_missing"

status_overlays_remerged="$(make_case status-overlays-remerged)"
print -r -- 'struct CompletionReplyCue: View {}' \
  >> "$status_overlays_remerged/Sources/CompanionApp/ContentView.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$status_overlays_remerged"

gesture_discovery_missing="$(make_case gesture-discovery-missing)"
rm "$gesture_discovery_missing/Sources/CompanionApp/CompanionGestureDiscoveryCoordinator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$gesture_discovery_missing"

gesture_discovery_remerged="$(make_case gesture-discovery-remerged)"
print -r -- 'private var gestureCoachTask: Task<Void, Never>?' \
  >> "$gesture_discovery_remerged/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$gesture_discovery_remerged"

gesture_discovery_unrelated="$(make_case gesture-discovery-unrelated)"
print -r -- 'let fixture = URLSession.shared' \
  >> "$gesture_discovery_unrelated/Sources/CompanionApp/CompanionGestureDiscoveryCoordinator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$gesture_discovery_unrelated"

gesture_discovery_delegate_missing="$(make_case gesture-discovery-delegate-missing)"
python3 - "$gesture_discovery_delegate_missing/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "gestureDiscovery.scheduleIfEligible(",
        "legacyGestureCoach.scheduleIfEligible(",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$gesture_discovery_delegate_missing"

presentation_runtime_missing="$(make_case presentation-runtime-missing)"
rm "$presentation_runtime_missing/Sources/CompanionApp/CompanionPresentationRuntimeCoordinator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$presentation_runtime_missing"

presentation_runtime_remerged="$(make_case presentation-runtime-remerged)"
print -r -- 'var presentationLifecycle = CompanionPresentationLifecycle()' \
  >> "$presentation_runtime_remerged/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$presentation_runtime_remerged"

presentation_runtime_unrelated="$(make_case presentation-runtime-unrelated)"
print -r -- 'let fixture = URLSession.shared' \
  >> "$presentation_runtime_unrelated/Sources/CompanionApp/CompanionPresentationRuntimeCoordinator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$presentation_runtime_unrelated"

presentation_runtime_delegate_missing="$(make_case presentation-runtime-delegate-missing)"
python3 - "$presentation_runtime_delegate_missing/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "presentationRuntime.beginContentSequence(",
        "legacyPresentationRuntime.beginContentSequence(",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$presentation_runtime_delegate_missing"

pet_feedback_runtime_missing="$(make_case pet-feedback-runtime-missing)"
rm "$pet_feedback_runtime_missing/Sources/CompanionApp/CompanionPetFeedbackRuntimeCoordinator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$pet_feedback_runtime_missing"

pet_feedback_runtime_remerged="$(make_case pet-feedback-runtime-remerged)"
print -r -- 'private var effectTask: Task<Void, Never>?' \
  >> "$pet_feedback_runtime_remerged/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$pet_feedback_runtime_remerged"

pet_feedback_runtime_capability="$(make_case pet-feedback-runtime-capability)"
print -r -- 'let fixture = UserDefaults.standard' \
  >> "$pet_feedback_runtime_capability/Sources/CompanionApp/CompanionPetFeedbackRuntimeCoordinator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$pet_feedback_runtime_capability"

pet_feedback_runtime_delegate_missing="$(make_case pet-feedback-runtime-delegate-missing)"
python3 - "$pet_feedback_runtime_delegate_missing/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "feedbackRuntime.schedulePoseReset(",
        "legacyFeedbackRuntime.schedulePoseReset(",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$pet_feedback_runtime_delegate_missing"

content_library_runtime_missing="$(make_case content-library-runtime-missing)"
rm "$content_library_runtime_missing/Sources/CompanionApp/CompanionContentLibraryRuntimeCoordinator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_library_runtime_missing"

content_library_runtime_remerged="$(make_case content-library-runtime-remerged)"
print -r -- 'private var reportedPackPlaybackKeys: Set<String> = []' \
  >> "$content_library_runtime_remerged/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_library_runtime_remerged"

content_library_runtime_capability="$(make_case content-library-runtime-capability)"
print -r -- 'let fixture = FileManager.default' \
  >> "$content_library_runtime_capability/Sources/CompanionApp/CompanionContentLibraryRuntimeCoordinator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_library_runtime_capability"

content_library_runtime_delegate_missing="$(make_case content-library-runtime-delegate-missing)"
python3 - "$content_library_runtime_delegate_missing/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "contentLibraryRuntime.startRecovery(",
        "legacyContentLibraryRuntime.startRecovery(",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_library_runtime_delegate_missing"

preference_store_missing="$(make_case preference-store-missing)"
rm "$preference_store_missing/Sources/CompanionApp/CompanionPreferenceStore.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$preference_store_missing"

preference_store_remerged="$(make_case preference-store-remerged)"
print -r -- 'private typealias Keys = CompanionDefaultsKeys' \
  >> "$preference_store_remerged/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$preference_store_remerged"

preference_store_capability="$(make_case preference-store-capability)"
print -r -- 'let fixture = URLSession.shared' \
  >> "$preference_store_capability/Sources/CompanionApp/CompanionPreferenceStore.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$preference_store_capability"

preference_store_delegate_missing="$(make_case preference-store-delegate-missing)"
python3 - "$preference_store_delegate_missing/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "let savedPreferences = preferenceStore.load().snapshot",
        "let savedPreferences = legacyPreferenceStore.load().snapshot",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$preference_store_delegate_missing"

settings_backup_projection_missing="$(make_case settings-backup-projection-missing)"
rm "$settings_backup_projection_missing/Sources/CompanionApp/CompanionSettingsBackupProjection.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$settings_backup_projection_missing"

settings_backup_projection_remerged="$(make_case settings-backup-projection-remerged)"
print -r -- 'let legacyBackup = CompanionSettingsV1()' \
  >> "$settings_backup_projection_remerged/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$settings_backup_projection_remerged"

settings_backup_projection_capability="$(make_case settings-backup-projection-capability)"
print -r -- 'let fixture = URLSession.shared' \
  >> "$settings_backup_projection_capability/Sources/CompanionApp/CompanionSettingsBackupProjection.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$settings_backup_projection_capability"

settings_backup_projection_delegate_missing="$(make_case settings-backup-projection-delegate-missing)"
python3 - "$settings_backup_projection_delegate_missing/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "CompanionSettingsBackupProjection.export(",
        "LegacySettingsBackupProjection.export(",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$settings_backup_projection_delegate_missing"

voice_selection_runtime_missing="$(make_case voice-selection-runtime-missing)"
rm "$voice_selection_runtime_missing/Sources/CompanionApp/CompanionVoiceSelectionRuntimeCoordinator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$voice_selection_runtime_missing"

voice_selection_runtime_remerged="$(make_case voice-selection-runtime-remerged)"
print -r -- 'private var recentVoiceLineIDs: [String] = []' \
  >> "$voice_selection_runtime_remerged/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$voice_selection_runtime_remerged"

voice_selection_runtime_capability="$(make_case voice-selection-runtime-capability)"
print -r -- 'let fixture = URLSession.shared' \
  >> "$voice_selection_runtime_capability/Sources/CompanionApp/CompanionVoiceSelectionRuntimeCoordinator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$voice_selection_runtime_capability"

voice_selection_runtime_delegate_missing="$(make_case voice-selection-runtime-delegate-missing)"
python3 - "$voice_selection_runtime_delegate_missing/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "voiceSelection.selectEvent(",
        "legacyVoiceSelection.selectEvent(",
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$voice_selection_runtime_delegate_missing"

event_ingress_missing="$(make_case event-ingress-missing)"
rm "$event_ingress_missing/Sources/CompanionApp/CompanionEventIngress.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$event_ingress_missing"

event_ingress_remerged="$(make_case event-ingress-remerged)"
print -r -- 'struct CodexTaskSignal {}' \
  >> "$event_ingress_remerged/Sources/CompanionApp/CompanionEventWatcher.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$event_ingress_remerged"

event_ingress_capability="$(make_case event-ingress-capability)"
print -r -- 'let fixture = FileManager.default' \
  >> "$event_ingress_capability/Sources/CompanionApp/CompanionEventIngress.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$event_ingress_capability"

event_ingress_delegate_missing="$(make_case event-ingress-delegate-missing)"
python3 - "$event_ingress_delegate_missing/Sources/CompanionApp/CompanionEventWatcher.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "CodexProtocolEventExtractor.signal(",
        "LegacyProtocolEventExtractor.signal(",
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$event_ingress_delegate_missing"

content_sequence_runtime_missing="$(make_case content-sequence-runtime-missing)"
rm "$content_sequence_runtime_missing/Sources/CompanionApp/CompanionContentSequenceRuntimeCoordinator.swift"
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_sequence_runtime_missing"

content_sequence_runtime_remerged="$(make_case content-sequence-runtime-remerged)"
print -r -- 'private var selectedContentAssetKey: String?' \
  >> "$content_sequence_runtime_remerged/Sources/CompanionApp/CompanionViewModel.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_sequence_runtime_remerged"

content_sequence_runtime_capability="$(make_case content-sequence-runtime-capability)"
print -r -- 'let fixture = URLSession.shared' \
  >> "$content_sequence_runtime_capability/Sources/CompanionApp/CompanionContentSequenceRuntimeCoordinator.swift"
expect_failure CORE_BOUNDARY_LAYER_VIOLATION "$content_sequence_runtime_capability"

content_sequence_runtime_delegate_missing="$(make_case content-sequence-runtime-delegate-missing)"
python3 - "$content_sequence_runtime_delegate_missing/Sources/CompanionApp/CompanionViewModel.swift" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(
    p.read_text(encoding="utf-8").replace(
        "contentSequenceRuntime.selectAndBegin(",
        "legacyContentSequenceRuntime.selectAndBegin(",
        1,
    ),
    encoding="utf-8",
)
PY
expect_failure CORE_BOUNDARY_REQUIRED_PATH_MISSING "$content_sequence_runtime_delegate_missing"

print "Core module boundary smoke: PASS (184/184)"
