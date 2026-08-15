#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
COMMON_SCRIPT="$PROJECT_DIR/scripts/app-bundle-common.sh"
ZIP_CREATOR="$PROJECT_DIR/scripts/create-portable-source-zip.py"
PYTHON_CHECKER="$PROJECT_DIR/scripts/check-python-runtime.sh"
OUTPUT_PATH=""
ARCHIVE_ROOT=""
ARCHIVE_ROOT_IS_DEFAULT=0

fail() {
  local code="$1"
  local message="$2"
  local action="$3"
  print -u2 "FAIL  [$code] $message"
  print -u2 "ACTION  $action"
  exit 1
}

usage() {
  print "Usage: ./scripts/build-portable-source.sh --output <archive.zip> [--root <archive-root>]"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --output)
      [[ "$#" -ge 2 ]] || fail \
        "SOURCE_PACKAGE_INVALID_ARGUMENT" \
        "The source-package output value is missing." \
        "Provide --output followed by a new .zip path, then retry."
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --root)
      [[ "$#" -ge 2 ]] || fail \
        "SOURCE_PACKAGE_INVALID_ARGUMENT" \
        "The source-package root value is missing." \
        "Provide --root followed by a safe name ending in -source, then retry."
      ARCHIVE_ROOT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail \
        "SOURCE_PACKAGE_INVALID_ARGUMENT" \
        "The source-package builder received an unknown option." \
        "Run scripts/build-portable-source.sh --help, correct the command, then retry."
      ;;
  esac
done

[[ -n "$OUTPUT_PATH" && "$OUTPUT_PATH" == *.zip ]] || fail \
  "SOURCE_PACKAGE_INVALID_ARGUMENT" \
  "A new .zip output path is required." \
  "Provide --output followed by a new .zip path, then retry."

if [[ ! -x "$PYTHON_CHECKER" ]]; then
  fail \
    "SOURCE_PACKAGE_SOURCE_MISSING" \
    "The source-package Python runtime checker is missing or not executable." \
    "Restore scripts/check-python-runtime.sh from a trusted checkout, then retry."
fi
set +e
python_runtime_receipt="$($PYTHON_CHECKER 2>&1)"
python_runtime_status=$?
set -e
if [[ "$python_runtime_status" -ne 0 ]]; then
  print -u2 -r -- "$python_runtime_receipt"
  exit "$python_runtime_status"
fi

source "$COMMON_SCRIPT"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PROJECT_DIR/Info.plist")"
SOURCE_FINGERPRINT="$(chengyin_source_fingerprint "$PROJECT_DIR")"
SOURCE_SHORT="$(chengyin_short_fingerprint "$SOURCE_FINGERPRINT")"
BUILD_IDENTITY="$VERSION+$BUILD.$SOURCE_SHORT"

if [[ -z "$ARCHIVE_ROOT" ]]; then
  ARCHIVE_ROOT_IS_DEFAULT=1
  ARCHIVE_ROOT="chengyin-portable-source-staging-source"
fi
if [[ ! "$ARCHIVE_ROOT" =~ '^[A-Za-z0-9._-]+-source$' ]]; then
  fail \
    "SOURCE_PACKAGE_INVALID_ARGUMENT" \
    "The archive root is unsafe or does not end in -source." \
    "Use only letters, numbers, dots, underscores and hyphens, ending in -source."
fi

OUTPUT_PATH="${OUTPUT_PATH:A}"
OUTPUT_DIR="${OUTPUT_PATH:h}"
mkdir -p "$OUTPUT_DIR"
if [[ ! -d "$OUTPUT_DIR" || -L "$OUTPUT_DIR" ]]; then
  fail \
    "SOURCE_PACKAGE_INVALID_ARGUMENT" \
    "The source-package output directory is not a regular local directory." \
    "Choose a regular local directory and retry."
fi
if [[ -e "$OUTPUT_PATH" || -L "$OUTPUT_PATH" ]]; then
  fail \
    "SOURCE_PACKAGE_OUTPUT_EXISTS" \
    "The requested source-package output already exists." \
    "Choose a new output name or move the previous artifact aside, then retry."
fi

ROOT_FILES=(
  .gitignore
  AGENTS.md
  CODE_OF_CONDUCT.md
  CODE_OF_CONDUCT.zh-Hans.md
  CONTRIBUTING.md
  CONTRIBUTING.en.md
  GOVERNANCE.md
  GOVERNANCE.zh-Hans.md
  Info.plist
  LICENSE
  LICENSE-SCOPE.md
  PUBLIC-CODE-ONLY.md
  Package.swift
  README.md
  README.en.md
  ROADMAP.md
  ROADMAP.zh-Hans.md
  SECURITY.md
  SECURITY.en.md
  SUPPORT.md
  SUPPORT.zh-Hans.md
)
ROOT_DIRECTORIES=(
  .github
  Schemas
  Skills
  Sources
  Tests
  Tools
  community
  docs
  examples
  packaging
  scripts
)
INCLUDED_PATHS=("${ROOT_FILES[@]}" "${ROOT_DIRECTORIES[@]}" release)
EXCLUDED_PATHS=(
  .agents
  .ai-bridge
  .build
  .codex
  .git
  dist
  video-production
  release/generated-artifacts
)

for required_path in \
  "${ROOT_FILES[@]}" \
  "${ROOT_DIRECTORIES[@]}" \
  release/README.md \
  release/release-gates.json \
  Schemas/contributor-check-receipt-v1.schema.json \
  Schemas/all-game-rewards-v1.schema.json \
  Schemas/source-package-v1.schema.json \
  Schemas/public-git-bootstrap-receipt-v1.schema.json \
  Schemas/product-boundary-receipt-v1.schema.json \
  Schemas/projection-authoring-receipt-v1.schema.json \
  Schemas/experience-authoring-receipt-v1.schema.json \
  Schemas/content-pack-scaffold-receipt-v1.schema.json \
  Schemas/content-pack-locale-matrix-v1.schema.json \
  Schemas/public-source-secret-audit-v1.schema.json \
  Schemas/english-first-use-visual-audit-v1.schema.json \
  Schemas/local-preview-receipt-v1.schema.json \
  Schemas/core-module-boundary-baseline-v1.json \
  Schemas/module-stewardship-v1.schema.json \
  Schemas/codex-app-server-turn-events-v1.schema.json \
  Schemas/starter-media-v1.schema.json \
  community/module-stewardship.json \
  Sources/CompanionApp/CompanionVideoPlayer.swift \
  Sources/CompanionApp/CompanionPlaybackCoordinator.swift \
  Sources/CompanionApp/CompanionContentSequenceView.swift \
  Sources/CompanionApp/CompanionMediaPresentation.swift \
  Sources/CompanionApp/CompanionStatusOverlays.swift \
  Sources/CompanionApp/CompanionGestureDiscoveryCoordinator.swift \
  Sources/CompanionApp/CompanionPresentationRuntimeCoordinator.swift \
  Sources/CompanionApp/CompanionPetFeedbackRuntimeCoordinator.swift \
  Sources/CompanionApp/CompanionContentLibraryRuntimeCoordinator.swift \
  Sources/CompanionApp/CompanionPreferenceStore.swift \
  Sources/CompanionApp/CompanionSettingsBackupProjection.swift \
  Sources/CompanionApp/CompanionVoiceSelectionRuntimeCoordinator.swift \
  Sources/CompanionApp/CompanionLifestyleRuntimeCoordinator.swift \
  Sources/CompanionApp/CompanionLifestyleEventProjection.swift \
  Sources/CompanionApp/CompanionLifestylePresentation.swift \
  Sources/CompanionApp/CompanionContentOperationModels.swift \
  Sources/CompanionApp/CompanionContentOperationReceiptFactory.swift \
  Sources/CompanionApp/CompanionBackupOperationsCoordinator.swift \
  Sources/CompanionApp/CompanionContentOperationsCoordinator.swift \
  Sources/CompanionApp/ContentPackRecoveryCatalog.swift \
  Sources/CompanionApp/CompanionContentPackRecoverySection.swift \
  Sources/CompanionApp/CompanionMicrogamePresentation.swift \
  Sources/CompanionApp/CompanionMicrogameCompletionPresentation.swift \
  Sources/CompanionApp/CompanionTaskCompletionPresentation.swift \
  Sources/CompanionApp/CompanionPetDragPresentation.swift \
  Sources/CompanionApp/CompanionMicrogameRuntimeCoordinator.swift \
  Sources/CompanionApp/CompanionExperienceRuntimeCoordinator.swift \
  Sources/CompanionApp/CompanionWorkdayRuntimeCoordinator.swift \
  Sources/CompanionApp/CompanionWorkdayApplicationProjection.swift \
  Sources/CompanionApp/CompanionSharedDayRuntimeCoordinator.swift \
  Sources/CompanionApp/CompanionFirstSessionRuntimeCoordinator.swift \
  Sources/CompanionApp/CompanionFirstSessionCoach.swift \
  Sources/CompanionApp/CompanionFirstSessionIntegration.swift \
  Sources/CompanionApp/CompanionRuntimeEnvironment.swift \
  Sources/CompanionApp/ContentPackProjectionEditor.swift \
  Sources/CompanionApp/CompanionDisplayCatalog.swift \
  Sources/CompanionApp/CompanionPresentationPreferences.swift \
  Sources/CompanionApp/CompanionPresentationSurface.swift \
  Sources/CompanionApp/CompanionWindowSettingsSection.swift \
  Sources/CompanionApp/CompanionPetInteractionSurface.swift \
	Sources/CompanionApp/ContentPackManifest.swift \
	Sources/CompanionApp/ContentPackManifestFieldValidator.swift \
	Sources/CompanionApp/ContentPackContributionValidationSupport.swift \
	Sources/CompanionApp/ContentPackRightsValidator.swift \
	Sources/CompanionApp/ContentPackAccessibilityValidator.swift \
	Sources/CompanionApp/ContentPackFallbackValidator.swift \
	Sources/CompanionApp/ContentPackContributionValidator.swift \
	Sources/CompanionApp/ContentPackPackageContentsValidator.swift \
	Sources/CompanionApp/ContentPackAssetFileValidator.swift \
	Sources/CompanionApp/ContentPackAssetProjectionValidator.swift \
	Sources/CompanionApp/ContentPackAssetValidator.swift \
	Sources/CompanionApp/ContentPackArchivePolicy.swift \
	Sources/CompanionApp/ContentPackArchiveImporter.swift \
	Sources/CompanionApp/ContentPackVideoDecodeFallback.swift \
	Sources/CompanionApp/ContentPackNonVideoMediaProbe.swift \
	Sources/CompanionApp/ContentPackVideoMediaProbe.swift \
	Sources/CompanionApp/ContentPackMediaProbe.swift \
	Sources/CompanionApp/ContentPackMediaCheckpointDecoder.swift \
	Sources/CompanionApp/ContentPackMediaQualityProbe.swift \
	Sources/CompanionApp/CompanionContentPackImportPanel.swift \
  Sources/CompanionApp/ContentPackTriggerContract.swift \
  Sources/CompanionApp/ContentPackRuntimeAccessibility.swift \
  Sources/CompanionApp/ContentPackPlaybackModels.swift \
  Sources/CompanionApp/ContentPackRuntimeCatalog.swift \
  Sources/CompanionApp/ContentPackRuntimeSelection.swift \
  Sources/CompanionApp/CompanionContentSequenceRuntimeCoordinator.swift \
  Sources/CompanionApp/CompanionMediaAccessibilityPresentation.swift \
  Sources/CompanionApp/CompanionFailureReceipt.swift \
  Sources/CompanionApp/SemanticVersion.swift \
  Sources/CompanionApp/CompanionEventSpool.swift \
  Sources/CompanionApp/CompanionEventIngress.swift \
  Sources/CompanionApp/CompanionEventWatcher.swift \
  Sources/CompanionApp/CompanionEventBridgeRepair.swift \
  Sources/CompanionApp/CompanionRuntimeSupport.swift \
  Sources/CompanionApp/CompanionRuntimeRepairCoordinator.swift \
  Sources/CompanionApp/CompanionRuntimeReadinessPresentation.swift \
  Sources/CompanionApp/CompanionRelationshipRuntimeCoordinator.swift \
  Sources/CompanionApp/CompanionRelationshipContentSelection.swift \
  Sources/CompanionApp/ContentPackStoreLayout.swift \
  Sources/CompanionApp/ContentPackActiveRecordRepository.swift \
  Sources/CompanionApp/ContentPackStoreLockCoordinator.swift \
  Sources/CompanionApp/ContentPackStoreRepository.swift \
  Sources/CompanionApp/ContentPackInstallPreflight.swift \
  Sources/CompanionApp/ContentPackInstallTransactions.swift \
  Sources/CompanionApp/ContentPackRecoveryTransactions.swift \
  Sources/CompanionApp/ContentPackPlaybackHealthTransactions.swift \
  Sources/CompanionApp/ContentPackStoreSnapshotProjection.swift \
  Sources/CompanionApp/ContentPackStoreMaintenanceTransactions.swift \
  Sources/CompanionApp/ContentPackStoreModels.swift \
  Sources/CompanionApp/ContentPackStoreDurability.swift \
  Sources/CompanionApp/CompanionContentLibraryModels.swift \
  Sources/CompanionApp/CompanionSupportDiagnosticsSection.swift \
  Sources/CompanionApp/CompanionAccessibility.swift \
  Sources/CompanionApp/CompanionWorkdayAdapter.swift \
  Sources/CompanionApp/CompanionWorkdayPresentation.swift \
  Sources/CompanionApp/CompanionEventPresentation.swift \
  Sources/CompanionApp/CompanionEventTriggerRouting.swift \
  scripts/lifestyle-runtime-coordinator-smoke.swift \
  Sources/CompanionApp/CompanionWindowVisibilityKeeper.swift \
  Sources/CompanionContracts/CompanionPresentationProjection.swift \
  Sources/CompanionContracts/CompanionPresentationSession.swift \
  Sources/CompanionContracts/CompanionPresentationLifecycle.swift \
  Sources/CompanionContracts/CompanionFirstSession.swift \
  Sources/CompanionContracts/CompanionPlaybackHealth.swift \
  Sources/CompanionContracts/CompanionPlayPaletteLayout.swift \
  Sources/CompanionContracts/CompanionLocaleResolutionPolicy.swift \
  Sources/CompanionContracts/CompanionRuntimeReadiness.swift \
  Sources/CompanionContracts/CompanionWorkdayState.swift \
  Sources/CompanionContracts/CompanionWorkDirector.swift \
  Sources/CompanionContracts/CompanionWorkdaySignalTrustPolicy.swift \
  Sources/CompanionContracts/CompanionWorkdayExperiencePolicy.swift \
  Sources/CompanionContracts/CompanionTaskCompletionPolicy.swift \
  Sources/CompanionContracts/CompanionPetDragPolicy.swift \
  Sources/CompanionContracts/CompanionMicrogameCompletionPolicy.swift \
  Sources/CompanionContracts/CompanionMicrogameSession.swift \
  Sources/CompanionContracts/CompanionMicrogameWindowPolicy.swift \
  Sources/CompanionContracts/CompanionProjectionAuthoring.swift \
  Sources/CompanionContracts/CompanionPresentationEnvironment.swift \
  Sources/CompanionContracts/CodexAppServerMapper.swift \
  Sources/CompanionApp/Resources/starter-media.json \
  docs/STARTER-MEDIA-CONTRACT.md \
  docs/STARTER-MEDIA-CONTRACT.zh-Hans.md \
  docs/CORE-MODULE-BOUNDARY.md \
  docs/CORE-MODULE-BOUNDARY.zh-Hans.md \
  docs/MODULE-STEWARDSHIP.md \
  docs/MODULE-STEWARDSHIP.zh-Hans.md \
  docs/CODEX-APP-SERVER-ADAPTER.md \
  docs/CODEX-APP-SERVER-ADAPTER.zh-Hans.md \
  docs/EVENT-SPOOL-SECURITY.md \
  docs/EVENT-SPOOL-SECURITY.zh-Hans.md \
  docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.md \
  docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.zh-Hans.md \
  docs/LOCAL-PREVIEW.md \
  docs/LOCAL-PREVIEW.zh-Hans.md \
  docs/PRODUCT-BOUNDARY.md \
  docs/PRODUCT-BOUNDARY.zh-Hans.md \
  scripts/audit-core-module-boundaries.py \
  scripts/audit-swift-compiler-boundaries.py \
  scripts/audit-module-stewardship.py \
  scripts/audit-swiftpm-package-graph.py \
  scripts/check-contribution.py \
  scripts/check-example-experience-pack.py \
  scripts/run-example-experience-pack-smoke.sh \
  scripts/audit-accessibility-localization.py \
  scripts/audit-portable-source.py \
  scripts/bootstrap-public-git.py \
  scripts/prepare-public-code-only.py \
  scripts/audit-public-source-secrets.py \
  scripts/audit-product-boundary.py \
  scripts/run-product-boundary-smoke.sh \
  scripts/run-public-source-secret-audit-smoke.sh \
  scripts/audit-starter-media.py \
  scripts/audit-local-runtime-identity.py \
  scripts/macos_process_inspection.py \
  scripts/local-preview.py \
  scripts/preview-local.sh \
  scripts/local-preview-smoke.py \
  scripts/local-preview-sleeper.swift \
  scripts/run-local-preview-smoke.sh \
  scripts/swift-build-cache.sh \
  scripts/run-swift-build-cache-smoke.sh \
  scripts/swift-toolchain-env.sh \
  scripts/run-swift-toolchain-env-smoke.sh \
  scripts/audit-direct-play-runtime.py \
  scripts/audit-all-game-rewards.py \
  scripts/game_reward_receipt_contract.py \
  scripts/run-game-reward-receipt-smoke.py \
  scripts/check-game-reward-audit-integration.py \
  scripts/check-python-runtime.sh \
  scripts/apply-content-pack-projection.py \
  scripts/apply-content-pack-experience.py \
  scripts/create-content-pack.py \
  scripts/new-content-pack.sh \
  scripts/run-content-pack-scaffold-smoke.sh \
  scripts/audit-content-pack-locales.sh \
  scripts/content-pack-locale-matrix-cli.swift \
  scripts/run-content-pack-locale-matrix-smoke.sh \
  scripts/author-content-pack-experience.sh \
  scripts/content-pack-creator-media-fallback.swift \
  scripts/check-presentation-runtime-integration.py \
  scripts/check-pet-feedback-runtime-integration.py \
  scripts/check-content-library-runtime-integration.py \
  scripts/check-preference-store-integration.py \
  scripts/check-settings-backup-projection-integration.py \
  scripts/check-voice-selection-runtime-integration.py \
  scripts/check-runtime-support-integration.py \
  scripts/check-relationship-runtime-integration.py \
  scripts/check-event-spool-integration.py \
  scripts/check-workday-integration.py \
  scripts/check-first-session-integration.py \
  scripts/check-english-first-use-audit-integration.py \
  scripts/check-microgame-integration.py \
  scripts/check-microgame-window-policy-integration.py \
  scripts/microgame-runtime-coordinator-smoke.swift \
  scripts/run-microgame-runtime-coordinator-smoke.sh \
  scripts/microgame-window-policy-smoke.swift \
  scripts/run-microgame-window-policy-smoke.sh \
  scripts/check-experience-runtime-integration.py \
  scripts/workday-runtime-coordinator-smoke.swift \
  scripts/run-workday-runtime-coordinator-smoke.sh \
  scripts/check-shared-day-integration.py \
  scripts/shared-day-runtime-coordinator-smoke.swift \
  scripts/run-shared-day-runtime-coordinator-smoke.sh \
  scripts/event-spool-smoke.swift \
  scripts/run-event-spool-smoke.sh \
  scripts/first-session-runtime-coordinator-smoke.swift \
  scripts/run-first-session-runtime-coordinator-smoke.sh \
  scripts/runtime-environment-smoke.swift \
  scripts/run-runtime-environment-smoke.sh \
  scripts/english-first-use-visual-audit.swift \
  scripts/run-english-first-use-visual-audit.sh \
  scripts/run-english-first-use-visual-audit-smoke.sh \
  scripts/experience-runtime-coordinator-smoke.swift \
  scripts/run-experience-runtime-coordinator-smoke.sh \
  scripts/check-window-visibility-integration.py \
  scripts/runtime-repair-smoke.swift \
  scripts/run-runtime-repair-smoke.sh \
  scripts/run-relationship-runtime-coordinator-smoke.sh \
  scripts/relationship-runtime-coordinator-smoke.swift \
  scripts/gesture-discovery-coordinator-smoke.swift \
  scripts/run-gesture-discovery-coordinator-smoke.sh \
  scripts/presentation-runtime-coordinator-smoke.swift \
  scripts/run-presentation-runtime-coordinator-smoke.sh \
  scripts/pet-feedback-runtime-coordinator-smoke.swift \
  scripts/run-pet-feedback-runtime-coordinator-smoke.sh \
  scripts/content-library-runtime-coordinator-smoke.swift \
  scripts/run-content-library-runtime-coordinator-smoke.sh \
  scripts/preference-store-smoke.swift \
  scripts/run-preference-store-smoke.sh \
  scripts/settings-backup-projection-smoke.swift \
  scripts/run-settings-backup-projection-smoke.sh \
  scripts/voice-selection-runtime-smoke.swift \
  scripts/run-voice-selection-runtime-smoke.sh \
  scripts/run-local-runtime-identity-smoke.sh \
  scripts/run-python-runtime-smoke.sh \
  scripts/direct-play-window-audit.swift \
  scripts/catch-game-smoke.swift \
  scripts/hide-game-smoke.swift \
  scripts/combo-game-smoke.swift \
  scripts/heart-trace-smoke.swift \
  scripts/rhythm-game-smoke.swift \
  scripts/feed-game-smoke.swift \
  scripts/playback-media-soak.swift \
  scripts/run-playback-media-soak.sh \
  scripts/run-playback-media-soak-smoke.sh \
  scripts/check-projection-authoring-integration.py \
  scripts/check-presentation-environment-integration.py \
	scripts/check-content-operations-integration.py \
	scripts/check-content-pack-store-modularity.py \
	scripts/check-content-pack-validator-modularity.py \
	scripts/check-content-pack-archive-integration.py \
	scripts/audit-content-pack-archive.sh \
	scripts/build-content-pack-archive.py \
	scripts/build-content-pack-archive.sh \
	scripts/content-pack-archive-audit-cli.swift \
	scripts/content-pack-archive-fixtures.py \
	scripts/run-content-pack-archive-smoke.sh \
  scripts/edit-content-pack-projection.sh \
  scripts/create-portable-source-zip.py \
  scripts/run-portable-source-smoke.sh \
  scripts/run-public-git-bootstrap-smoke.sh \
  scripts/prepare-public-code-only.py \
  scripts/run-content-pack-projection-editor-smoke.sh \
  scripts/run-projection-receipt-apply-smoke.sh \
  scripts/run-content-pack-experience-authoring-smoke.sh \
  scripts/run-core-module-boundary-smoke.sh \
  scripts/run-swift-compiler-boundary-smoke.sh \
  scripts/run-swiftpm-package-graph-smoke.sh \
  scripts/run-module-stewardship-smoke.sh \
  scripts/run-codex-app-server-adapter-smoke.sh \
  scripts/run-contributor-check-smoke.sh \
  scripts/run-accessibility-localization-smoke.sh \
  scripts/run-starter-media-contract-smoke.sh \
  scripts/refresh-starter-media-manifest.py; do
  if [[ ! -e "$PROJECT_DIR/$required_path" || -L "$PROJECT_DIR/$required_path" ]]; then
    fail \
      "SOURCE_PACKAGE_SOURCE_MISSING" \
      "A required repository path is missing or unsafe: $required_path" \
      "Restore a complete checkout, run scripts/doctor.sh, then rebuild the source package."
  fi
done

if ! PYTHONDONTWRITEBYTECODE=1 python3 \
  "$PROJECT_DIR/scripts/audit-product-boundary.py" \
  --root "$PROJECT_DIR" \
  --scope development; then
  exit 1
fi

if ! PYTHONDONTWRITEBYTECODE=1 python3 \
  "$PROJECT_DIR/scripts/audit-public-source-secrets.py" \
  --root "$PROJECT_DIR"; then
  exit 1
fi

MEDIA_RIGHTS_STATUS="$(/usr/bin/plutil -extract mediaRights.status raw -o - "$PROJECT_DIR/release/release-gates.json")"
FINAL_LICENSE_STATUS="$(/usr/bin/plutil -extract finalLicense.status raw -o - "$PROJECT_DIR/release/release-gates.json")"
DEVELOPER_ID_STATUS="$(/usr/bin/plutil -extract developerID.status raw -o - "$PROJECT_DIR/release/release-gates.json")"
NOTARIZATION_STATUS="$(/usr/bin/plutil -extract notarization.status raw -o - "$PROJECT_DIR/release/release-gates.json")"
OWNER_RELEASE_STATUS="$(/usr/bin/plutil -extract ownerReleaseApproval.status raw -o - "$PROJECT_DIR/release/release-gates.json")"

STAGING_ROOT="$(mktemp -d "$OUTPUT_DIR/.portable-source.XXXXXX")"
SOURCE_ROOT="$STAGING_ROOT/$ARCHIVE_ROOT"
STAGED_ZIP="$STAGING_ROOT/$ARCHIVE_ROOT.zip"

cleanup() {
  if [[ -n "${STAGING_ROOT:-}" \
    && "$STAGING_ROOT" == "$OUTPUT_DIR"/.portable-source.* \
    && -d "$STAGING_ROOT" ]]; then
    /bin/rm -rf "$STAGING_ROOT"
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$SOURCE_ROOT/release"
for relative_path in "${ROOT_FILES[@]}" "${ROOT_DIRECTORIES[@]}"; do
  if ! ditto "$PROJECT_DIR/$relative_path" "$SOURCE_ROOT/$relative_path"; then
    fail \
      "SOURCE_PACKAGE_BUILD_FAILED" \
      "A required source-package path could not be staged." \
      "Check local storage and repository readability, then retry."
  fi
done
cp "$PROJECT_DIR/release/README.md" "$SOURCE_ROOT/release/README.md"
cp "$PROJECT_DIR/release/release-gates.json" "$SOURCE_ROOT/release/release-gates.json"

find "$SOURCE_ROOT" -type d -name '__pycache__' -prune -exec /bin/rm -rf -- {} +
find "$SOURCE_ROOT" -type f \( -name '*.pyc' -o -name '.DS_Store' \) -delete

if ! PYTHONDONTWRITEBYTECODE=1 python3 \
  "$SOURCE_ROOT/scripts/audit-product-boundary.py" \
  --root "$SOURCE_ROOT" \
  --scope public; then
  exit 1
fi

SOURCE_PACKAGE_FINGERPRINT="$( (
  cd "$SOURCE_ROOT"
  while IFS= read -r -d '' relative_path; do
    relative_path="${relative_path#./}"
    checksum="$(shasum -a 256 "$relative_path" | awk '{ print $1 }')"
    printf '%s\0%s\0' "$relative_path" "$checksum"
  done < <(find . -type f \
    ! -name SOURCE-PACKAGE.json \
    ! -name SOURCE-SHA256SUMS.txt \
    -print0 | LC_ALL=C sort -z)
) | shasum -a 256 | awk '{ print $1 }')"
SOURCE_PACKAGE_SHORT="$(chengyin_short_fingerprint "$SOURCE_PACKAGE_FINGERPRINT")"
SOURCE_PACKAGE_IDENTITY="$BUILD_IDENTITY.src.$SOURCE_PACKAGE_SHORT"

if [[ "$ARCHIVE_ROOT_IS_DEFAULT" -eq 1 ]]; then
  FINAL_ARCHIVE_ROOT="Chengyin-Companion-$VERSION-$BUILD-$SOURCE_SHORT-src-$SOURCE_PACKAGE_SHORT-macos-arm64-preview-source"
  if ! /bin/mv "$SOURCE_ROOT" "$STAGING_ROOT/$FINAL_ARCHIVE_ROOT"; then
    fail \
      "SOURCE_PACKAGE_BUILD_FAILED" \
      "The staged source package could not receive its content-addressed root." \
      "Check local storage and retry from a stable checkout."
  fi
  ARCHIVE_ROOT="$FINAL_ARCHIVE_ROOT"
  SOURCE_ROOT="$STAGING_ROOT/$ARCHIVE_ROOT"
fi
STAGED_ZIP="$STAGING_ROOT/$ARCHIVE_ROOT.zip"

write_path_array() {
  local -a values=("${(@P)1}")
  local index
  local comma
  for (( index = 1; index <= ${#values[@]}; index++ )); do
    comma=","
    if (( index == ${#values[@]} )); then
      comma=""
    fi
    printf '    "%s"%s\n' "${values[$index]}" "$comma"
  done
}

{
  print -r -- "{"
  print -r -- '  "schemaVersion": 1,'
  print -r -- '  "artifactKind": "source-preview",'
  print -r -- '  "product": "Chengyin Companion",'
  print -r -- "  \"archiveRoot\": \"$ARCHIVE_ROOT\","
  print -r -- "  \"appVersion\": \"$VERSION\","
  print -r -- "  \"appBuild\": \"$BUILD\","
  print -r -- "  \"appSourceFingerprint\": \"$SOURCE_FINGERPRINT\","
  print -r -- "  \"buildIdentity\": \"$BUILD_IDENTITY\","
  print -r -- "  \"sourcePackageFingerprint\": \"$SOURCE_PACKAGE_FINGERPRINT\","
  print -r -- "  \"sourcePackageIdentity\": \"$SOURCE_PACKAGE_IDENTITY\","
  print -r -- '  "platform": {'
  print -r -- '    "os": "macOS",'
  print -r -- '    "minimumVersion": "14.0",'
  print -r -- '    "architectures": ["arm64"]'
  print -r -- '  },'
  print -r -- '  "completenessProfile": "clone-build-contribute-v1",'
  print -r -- '  "integrityScope": "internal-consistency-not-authenticity",'
  print -r -- '  "includedPaths": ['
  write_path_array INCLUDED_PATHS
  print -r -- '  ],'
  print -r -- '  "excludedPaths": ['
  write_path_array EXCLUDED_PATHS
  print -r -- '  ],'
  print -r -- '  "checksumsFile": "SOURCE-SHA256SUMS.txt",'
  print -r -- '  "releaseGateRegistry": "release/release-gates.json",'
  print -r -- '  "releaseGates": {'
  print -r -- "    \"mediaRights\": \"$MEDIA_RIGHTS_STATUS\","
  print -r -- "    \"finalLicense\": \"$FINAL_LICENSE_STATUS\","
  print -r -- "    \"developerID\": \"$DEVELOPER_ID_STATUS\","
  print -r -- "    \"notarization\": \"$NOTARIZATION_STATUS\","
  print -r -- "    \"ownerReleaseApproval\": \"$OWNER_RELEASE_STATUS\","
  print -r -- '    "publicRelease": "not-ready"'
  print -r -- '  }'
  print -r -- "}"
} > "$SOURCE_ROOT/SOURCE-PACKAGE.json"

(
  cd "$SOURCE_ROOT"
  : > SOURCE-SHA256SUMS.txt
  while IFS= read -r -d '' relative_path; do
    relative_path="${relative_path#./}"
    checksum="$(shasum -a 256 "$relative_path" | awk '{ print $1 }')"
    printf '%s  %s\n' "$checksum" "$relative_path" >> SOURCE-SHA256SUMS.txt
  done < <(find . -type f ! -name SOURCE-SHA256SUMS.txt -print0 | sort -z)
)

if ! python3 "$ZIP_CREATOR" "$SOURCE_ROOT" "$STAGED_ZIP"; then
  fail \
    "SOURCE_PACKAGE_BUILD_FAILED" \
    "The staged source archive could not be created." \
    "Check local storage and archive tools, then retry."
fi
if ! /bin/ln "$STAGED_ZIP" "$OUTPUT_PATH" 2>/dev/null; then
  fail \
    "SOURCE_PACKAGE_OUTPUT_EXISTS" \
    "The source-package output changed during publication." \
    "Choose a new output name and retry."
fi

print -r -- "$OUTPUT_PATH"
