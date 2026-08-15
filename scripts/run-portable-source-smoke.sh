#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE 2>/dev/null || true

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
BUILDER="$PROJECT_DIR/scripts/build-portable-source.sh"
AUDITOR="$PROJECT_DIR/scripts/audit-portable-source.py"
SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chengyin-source-package-smoke.XXXXXX")"
ARCHIVE_ROOT="chengyin-source-contract-smoke-source"
ARCHIVE_PATH="$SMOKE_ROOT/$ARCHIVE_ROOT.zip"
DEFAULT_ARCHIVE="$SMOKE_ROOT/default-root.zip"
UNPACK_ROOT="$SMOKE_ROOT/unpacked"
TAMPER_PARENT="$SMOKE_ROOT/tampered"
TAMPER_ARCHIVE="$SMOKE_ROOT/tampered-source.zip"
COHERENT_PARENT="$SMOKE_ROOT/coherent-repack"
COHERENT_ARCHIVE="$SMOKE_ROOT/coherent-repack-source.zip"
SECRET_PARENT="$SMOKE_ROOT/secret-repack"
SECRET_ARCHIVE="$SMOKE_ROOT/secret-repack-source.zip"
UNSAFE_ARCHIVE="$SMOKE_ROOT/unsafe-source.zip"
PLAYBACK_SOAK_STATUS_FILE="$SMOKE_ROOT/playback-soak-status"
ISOLATED_SETTINGS_PATH=""
ISOLATED_SETTINGS_SHA256=""

cleanup() {
  if [[ -n "${SMOKE_ROOT:-}" \
    && "$SMOKE_ROOT" == "${TMPDIR:-/tmp}"/chengyin-source-package-smoke.* \
    && -d "$SMOKE_ROOT" ]]; then
    /bin/rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

fail() {
  print -u2 "FAIL  $1"
  exit 1
}

assert_isolated_source_sentinel() {
  local label="$1"
  local current_sha256
  if [[ -z "$ISOLATED_SETTINGS_PATH" || -z "$ISOLATED_SETTINGS_SHA256" ]]; then
    return 0
  fi
  [[ -f "$ISOLATED_SETTINGS_PATH" && ! -L "$ISOLATED_SETTINGS_PATH" ]] \
    || fail "isolated source sentinel changed during $label"
  current_sha256="$(shasum -a 256 "$ISOLATED_SETTINGS_PATH" | awk '{ print $1 }')"
  [[ "$current_sha256" == "$ISOLATED_SETTINGS_SHA256" ]] \
    || fail "isolated source sentinel changed during $label"
}

run_quiet_check() {
  local label="$1"
  local exit_status
  local log_path
  shift
  log_path="$SMOKE_ROOT/check-$label.log"
  assert_isolated_source_sentinel "$label precheck"
  set +e
  "$@" >"$log_path" 2>&1
  exit_status=$?
  set -e
  assert_isolated_source_sentinel "$label postcheck"
  if [[ "$exit_status" -ne 0 ]]; then
    print -u2 "DETAIL  redacted tail for $label:"
    PYTHONDONTWRITEBYTECODE=1 python3 - "$log_path" <<'PY'
from pathlib import Path
import os
import re
import sys

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8", errors="replace").splitlines()[-24:]
private_path = re.compile(r"/(?:Users|Volumes|private|var|tmp)/[^\s\"']+")
username = os.environ.get("USER", "")
for line in lines:
    safe = private_path.sub("<private-path>", line)
    if username:
        safe = safe.replace(username, "<user>")
    print(f"DETAIL  {safe[:600]}", file=sys.stderr)
PY
    fail "isolated source check failed: $label"
  fi
  /bin/rm -f "$log_path"
}

run_playback_soak_check() {
  local output
  local exit_status
  assert_isolated_source_sentinel "playback-soak precheck"
  set +e
  output="$("$@" 2>&1)"
  exit_status=$?
  set -e
  assert_isolated_source_sentinel "playback-soak postcheck"
  if [[ "$exit_status" -ne 0 ]]; then
    print -u2 -- "$output"
    fail "isolated source check failed: playback-soak"
  fi
  if [[ "$output" == *"Playback media soak smoke: PASS_WITH_PENDING"* ]]; then
    print -r -- "PENDING" > "$PLAYBACK_SOAK_STATUS_FILE"
  elif [[ "$output" == *"Playback media soak smoke: PASS"* ]]; then
    print -r -- "PASS" > "$PLAYBACK_SOAK_STATUS_FILE"
  else
    print -u2 -- "$output"
    fail "playback soak returned no recognized tri-state receipt"
  fi
}

KEY_SOURCES=(
  scripts/build-portable-source.sh
  scripts/audit-portable-source.py
  scripts/audit-public-source-secrets.py
  scripts/audit-product-boundary.py
  scripts/run-product-boundary-smoke.sh
  Schemas/product-boundary-receipt-v1.schema.json
  scripts/bootstrap-public-git.py
  scripts/prepare-public-code-only.py
  scripts/run-public-git-bootstrap-smoke.sh
  Schemas/public-git-bootstrap-receipt-v1.schema.json
  scripts/run-public-source-secret-audit-smoke.sh
  Schemas/public-source-secret-audit-v1.schema.json
  scripts/run-portable-source-smoke.sh
  scripts/build-creator-tool.sh
  scripts/content-pack-creator-media-fallback.swift
  Sources/CompanionApp/ContentPackVideoDecodeFallback.swift
  Sources/CompanionApp/ContentPackNonVideoMediaProbe.swift
  Sources/CompanionApp/ContentPackVideoMediaProbe.swift
  Sources/CompanionApp/ContentPackMediaProbe.swift
  Sources/CompanionApp/ContentPackMediaCheckpointDecoder.swift
  Sources/CompanionApp/ContentPackMediaQualityProbe.swift
  scripts/audit-content-pack-archive.sh
  scripts/build-content-pack-archive.py
  scripts/build-content-pack-archive.sh
  scripts/content-pack-archive-audit-cli.swift
  scripts/content-pack-archive-fixtures.py
  scripts/run-content-pack-archive-smoke.sh
  scripts/check-content-pack-archive-integration.py
  scripts/run-content-pack-v2-contract-matrix.sh
  scripts/run-content-pack-projection-editor-smoke.sh
  scripts/run-projection-receipt-apply-smoke.sh
  scripts/run-content-pack-experience-authoring-smoke.sh
  scripts/apply-content-pack-experience.py
  scripts/create-content-pack.py
  scripts/new-content-pack.sh
  scripts/run-content-pack-scaffold-smoke.sh
  Schemas/content-pack-scaffold-receipt-v1.schema.json
  scripts/audit-content-pack-locales.sh
  scripts/content-pack-locale-matrix-cli.swift
  scripts/run-content-pack-locale-matrix-smoke.sh
  Schemas/content-pack-locale-matrix-v1.schema.json
  scripts/check-projection-authoring-integration.py
  scripts/check-presentation-environment-integration.py
  scripts/check-presentation-runtime-integration.py
  scripts/check-microgame-window-policy-integration.py
  scripts/check-pet-feedback-runtime-integration.py
  scripts/check-content-library-runtime-integration.py
  scripts/check-preference-store-integration.py
  scripts/check-settings-backup-projection-integration.py
  scripts/check-voice-selection-runtime-integration.py
  scripts/check-runtime-support-integration.py
  scripts/check-relationship-runtime-integration.py
  scripts/check-content-pack-store-modularity.py
  scripts/check-content-pack-validator-modularity.py
  scripts/check-event-spool-integration.py
  scripts/audit-local-runtime-identity.py
  scripts/macos_process_inspection.py
  scripts/run-local-runtime-identity-smoke.sh
  Sources/CompanionApp/CompanionContentOperationModels.swift
  Sources/CompanionApp/CompanionContentOperationReceiptFactory.swift
  Sources/CompanionApp/CompanionBackupOperationsCoordinator.swift
  Sources/CompanionApp/CompanionContentOperationsCoordinator.swift
  Sources/CompanionApp/CompanionMicrogamePresentation.swift
  Sources/CompanionApp/CompanionMicrogameCompletionPresentation.swift
  Sources/CompanionApp/CompanionTaskCompletionPresentation.swift
  Sources/CompanionApp/CompanionPetDragPresentation.swift
  Sources/CompanionContracts/CompanionTaskCompletionPolicy.swift
  Sources/CompanionContracts/CompanionMicrogameWindowPolicy.swift
  Sources/CompanionContracts/CompanionPetDragPolicy.swift
  Sources/CompanionContracts/CompanionLocaleResolutionPolicy.swift
  Sources/CompanionApp/ContentPackPlaybackModels.swift
  Sources/CompanionApp/ContentPackRuntimeCatalog.swift
  Sources/CompanionApp/ContentPackRuntimeSelection.swift
  Sources/CompanionApp/CompanionContentSequenceRuntimeCoordinator.swift
  Sources/CompanionApp/CompanionRuntimeSupport.swift
  Sources/CompanionApp/CompanionRuntimeRepairCoordinator.swift
  Sources/CompanionApp/CompanionRuntimeReadinessPresentation.swift
  Sources/CompanionApp/CompanionRelationshipRuntimeCoordinator.swift
  Sources/CompanionApp/CompanionRelationshipContentSelection.swift
  Sources/CompanionApp/CompanionGestureDiscoveryCoordinator.swift
  Sources/CompanionApp/CompanionPresentationRuntimeCoordinator.swift
  Sources/CompanionApp/CompanionPetFeedbackRuntimeCoordinator.swift
  Sources/CompanionApp/CompanionContentLibraryRuntimeCoordinator.swift
  Sources/CompanionApp/CompanionPreferenceStore.swift
  Sources/CompanionApp/CompanionSettingsBackupProjection.swift
  Sources/CompanionApp/CompanionVoiceSelectionRuntimeCoordinator.swift
  Sources/CompanionApp/CompanionLifestyleEventProjection.swift
  Sources/CompanionApp/CompanionLifestylePresentation.swift
  Sources/CompanionApp/ContentPackStoreModels.swift
  Sources/CompanionApp/ContentPackStoreDurability.swift
  Sources/CompanionApp/ContentPackStoreLayout.swift
  Sources/CompanionApp/ContentPackActiveRecordRepository.swift
  Sources/CompanionApp/ContentPackStoreLockCoordinator.swift
  Sources/CompanionApp/ContentPackStoreRepository.swift
  Sources/CompanionApp/ContentPackStore.swift
  Sources/CompanionApp/ContentPackInstallTransactions.swift
  Sources/CompanionApp/ContentPackPlaybackHealthTransactions.swift
  Sources/CompanionApp/ContentPackStoreSnapshotProjection.swift
  Sources/CompanionApp/ContentPackStoreMaintenanceTransactions.swift
  Sources/CompanionApp/CompanionContentLibraryModels.swift
  Sources/CompanionApp/ContentPackVideoDecodeFallback.swift
  Sources/CompanionApp/ContentPackNonVideoMediaProbe.swift
  Sources/CompanionApp/ContentPackVideoMediaProbe.swift
  Sources/CompanionApp/ContentPackMediaProbe.swift
  Sources/CompanionApp/ContentPackMediaCheckpointDecoder.swift
  Sources/CompanionApp/ContentPackMediaQualityProbe.swift
  Sources/CompanionApp/ContentPackManifestFieldValidator.swift
  Sources/CompanionApp/ContentPackContributionValidationSupport.swift
  Sources/CompanionApp/ContentPackRightsValidator.swift
  Sources/CompanionApp/ContentPackAccessibilityValidator.swift
  Sources/CompanionApp/ContentPackFallbackValidator.swift
  Sources/CompanionApp/ContentPackContributionValidator.swift
  Sources/CompanionApp/ContentPackPackageContentsValidator.swift
  Sources/CompanionApp/ContentPackAssetFileValidator.swift
  Sources/CompanionApp/ContentPackAssetProjectionValidator.swift
  Sources/CompanionApp/ContentPackAssetValidator.swift
  scripts/content-pack-creator-media-fallback.swift
  scripts/local-preview.py
  scripts/preview-local.sh
  scripts/local-preview-smoke.py
  scripts/local-preview-sleeper.swift
  scripts/run-local-preview-smoke.sh
  scripts/swift-build-cache.sh
  scripts/run-swift-build-cache-smoke.sh
  scripts/swift-toolchain-env.sh
  scripts/run-swift-toolchain-env-smoke.sh
  Schemas/local-preview-receipt-v1.schema.json
  Schemas/all-game-rewards-v1.schema.json
  scripts/audit-direct-play-runtime.py
  scripts/audit-all-game-rewards.py
  scripts/game_reward_receipt_contract.py
  scripts/run-game-reward-receipt-smoke.py
  scripts/check-game-reward-audit-integration.py
  scripts/check-python-runtime.sh
  scripts/run-python-runtime-smoke.sh
  scripts/direct-play-window-audit.swift
  scripts/catch-game-smoke.swift
  scripts/hide-game-smoke.swift
  scripts/combo-game-smoke.swift
  scripts/heart-trace-smoke.swift
  scripts/rhythm-game-smoke.swift
  scripts/feed-game-smoke.swift
  scripts/check-workday-integration.py
  scripts/check-shared-day-integration.py
  scripts/check-window-visibility-integration.py
  scripts/runtime-repair-smoke.swift
  scripts/run-runtime-repair-smoke.sh
  scripts/run-relationship-runtime-coordinator-smoke.sh
  scripts/relationship-runtime-coordinator-smoke.swift
  scripts/gesture-discovery-coordinator-smoke.swift
  scripts/run-gesture-discovery-coordinator-smoke.sh
  scripts/presentation-runtime-coordinator-smoke.swift
  scripts/run-presentation-runtime-coordinator-smoke.sh
  scripts/microgame-window-policy-smoke.swift
  scripts/run-microgame-window-policy-smoke.sh
  scripts/pet-feedback-runtime-coordinator-smoke.swift
  scripts/run-pet-feedback-runtime-coordinator-smoke.sh
  scripts/content-library-runtime-coordinator-smoke.swift
  scripts/run-content-library-runtime-coordinator-smoke.sh
  scripts/preference-store-smoke.swift
  scripts/run-preference-store-smoke.sh
  scripts/settings-backup-projection-smoke.swift
  scripts/run-settings-backup-projection-smoke.sh
  scripts/voice-selection-runtime-smoke.swift
  scripts/run-voice-selection-runtime-smoke.sh
  scripts/playback-media-soak.swift
  scripts/run-playback-media-soak.sh
  scripts/run-playback-media-soak-smoke.sh
  scripts/audit-starter-media.py
  scripts/refresh-starter-media-manifest.py
  scripts/run-starter-media-contract-smoke.sh
  scripts/audit-core-module-boundaries.py
  scripts/audit-swift-compiler-boundaries.py
  scripts/audit-module-stewardship.py
  scripts/audit-swiftpm-package-graph.py
  scripts/audit-accessibility-localization.py
  scripts/run-core-module-boundary-smoke.sh
  scripts/run-swift-compiler-boundary-smoke.sh
  scripts/run-swiftpm-package-graph-smoke.sh
  scripts/run-module-stewardship-smoke.sh
  scripts/run-codex-app-server-adapter-smoke.sh
  scripts/run-accessibility-localization-smoke.sh
  scripts/run-microgame-runtime-coordinator-smoke.sh
  scripts/run-experience-runtime-coordinator-smoke.sh
  scripts/run-workday-runtime-coordinator-smoke.sh
  scripts/shared-day-runtime-coordinator-smoke.swift
  scripts/run-shared-day-runtime-coordinator-smoke.sh
  scripts/event-spool-smoke.swift
  scripts/run-event-spool-smoke.sh
  scripts/check-first-session-integration.py
  scripts/run-first-session-runtime-coordinator-smoke.sh
  scripts/check-english-first-use-audit-integration.py
  scripts/english-first-use-visual-audit.swift
  scripts/run-english-first-use-visual-audit.sh
  scripts/run-english-first-use-visual-audit-smoke.sh
  scripts/runtime-environment-smoke.swift
  scripts/run-runtime-environment-smoke.sh
  scripts/check-contribution.py
  scripts/run-contributor-check-smoke.sh
  Schemas/contributor-check-receipt-v1.schema.json
  Schemas/source-package-v1.schema.json
  Schemas/module-stewardship-v1.schema.json
  Schemas/codex-app-server-turn-events-v1.schema.json
  Schemas/english-first-use-visual-audit-v1.schema.json
  community/module-stewardship.json
  docs/MODULE-STEWARDSHIP.md
  docs/MODULE-STEWARDSHIP.zh-Hans.md
  docs/CODEX-APP-SERVER-ADAPTER.md
  docs/CODEX-APP-SERVER-ADAPTER.zh-Hans.md
  docs/EVENT-SPOOL-SECURITY.md
  docs/EVENT-SPOOL-SECURITY.zh-Hans.md
  docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.md
  docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.zh-Hans.md
  docs/SOURCE-PACKAGE-CONTRACT.md
  docs/SOURCE-PACKAGE-CONTRACT.zh-Hans.md
)
SOURCE_SHA_BEFORE="$({
  for source_path in "${KEY_SOURCES[@]}"; do
    print -r -- "$source_path"
    shasum -a 256 "$PROJECT_DIR/$source_path" | awk '{ print $1 }'
  done
} | shasum -a 256 | awk '{ print $1 }')"

"$BUILDER" --output "$ARCHIVE_PATH" --root "$ARCHIVE_ROOT" >/dev/null
[[ -f "$ARCHIVE_PATH" && ! -L "$ARCHIVE_PATH" && -s "$ARCHIVE_PATH" ]] \
  || fail "source-package builder did not publish a regular non-empty ZIP"

[[ ! -e "$PROJECT_DIR/scripts/__pycache__" ]] \
  || fail "source tree contains Python bytecode cache before archive audit"
VALID_RECEIPT="$($AUDITOR "$ARCHIVE_PATH" --json)"
[[ ! -e "$PROJECT_DIR/scripts/__pycache__" ]] \
  || fail "archive auditor created a source-tree Python bytecode cache"
SOURCE_RECEIPT="$VALID_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["status"] == "PASS", receipt
assert receipt["contract"] == "clone-build-contribute-v1", receipt
assert receipt["releaseState"] == "NOT_PUBLIC_RELEASE_READY", receipt
assert receipt["fileCount"] > 100, receipt
assert len(receipt["sourcePackageFingerprint"]) == 64, receipt
assert receipt["sourcePackageIdentity"].endswith(
    ".src." + receipt["sourcePackageFingerprint"][:12]
), receipt
assert receipt["productBoundary"]["contract"] == "chengyin.product-boundary/v1", receipt
assert receipt["productBoundary"]["status"] == "PASS", receipt
assert receipt["productBoundary"]["scope"] == "public", receipt
assert receipt["productBoundary"]["forbiddenFindingCount"] == 0, receipt
assert receipt["productBoundary"]["historicalResearchState"] == "excluded", receipt
assert receipt["productBoundary"]["networkRequired"] is False, receipt
assert receipt["productBoundary"]["environmentValuesRead"] is False, receipt
assert receipt["productBoundary"]["applicationsDirectoryModified"] is False, receipt
assert receipt["productBoundary"]["contentExcerptsIncluded"] is False, receipt
assert receipt["secretAudit"]["contract"] == "chengyin.public-source-secret-audit/v1", receipt
assert receipt["secretAudit"]["status"] == "PASS", receipt
assert receipt["secretAudit"]["findingCount"] == 0, receipt
assert receipt["secretAudit"]["environmentValuesRead"] is False, receipt
assert receipt["secretAudit"]["contentExcerptsIncluded"] is False, receipt
PY

"$BUILDER" --output "$DEFAULT_ARCHIVE" >/dev/null
DEFAULT_RECEIPT="$($AUDITOR "$DEFAULT_ARCHIVE" --json)"
SOURCE_RECEIPT="$DEFAULT_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["status"] == "PASS", receipt
assert receipt["archiveRoot"].endswith("-source"), receipt
assert "-src-" + receipt["sourcePackageFingerprint"][:12] + "-" in receipt["archiveRoot"], receipt
PY

set +e
INVALID_ROOT_RECEIPT="$($BUILDER \
  --output "$SMOKE_ROOT/invalid-root.zip" \
  --root '../invalid-source' 2>&1)"
INVALID_ROOT_STATUS=$?
set -e
[[ "$INVALID_ROOT_STATUS" -eq 1 \
  && "$INVALID_ROOT_RECEIPT" == *"[SOURCE_PACKAGE_INVALID_ARGUMENT]"* \
  && "$INVALID_ROOT_RECEIPT" == *"ACTION"* ]] \
  || fail "unsafe explicit archive root did not return a stable rejection"

mkdir -p "$UNPACK_ROOT" "$TAMPER_PARENT"
ditto -x -k "$ARCHIVE_PATH" "$UNPACK_ROOT"
EXTRACTED_PROJECT="$UNPACK_ROOT/$ARCHIVE_ROOT"
ISOLATED_SETTINGS_PATH="$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionSettings.swift"
[[ -f "$ISOLATED_SETTINGS_PATH" && ! -L "$ISOLATED_SETTINGS_PATH" ]] \
  || fail "valid source archive lost the isolated source sentinel"
ISOLATED_SETTINGS_SHA256="$(shasum -a 256 "$ISOLATED_SETTINGS_PATH" | awk '{ print $1 }')"
[[ -f "$EXTRACTED_PROJECT/Schemas/contributor-check-receipt-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/all-game-rewards-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/source-package-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/public-git-bootstrap-receipt-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/product-boundary-receipt-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/projection-authoring-receipt-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/experience-authoring-receipt-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/content-pack-scaffold-receipt-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/content-pack-locale-matrix-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/public-source-secret-audit-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/starter-media-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/core-module-boundary-baseline-v1.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/module-stewardship-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/codex-app-server-turn-events-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/Schemas/english-first-use-visual-audit-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/community/module-stewardship.json" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionPresentationLifecycle.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionFirstSession.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CodexAppServerMapper.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/audit-accessibility-localization.py" \
  && -x "$EXTRACTED_PROJECT/scripts/run-accessibility-localization-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/audit-swift-compiler-boundaries.py" \
  && -x "$EXTRACTED_PROJECT/scripts/run-swift-compiler-boundary-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/audit-swiftpm-package-graph.py" \
  && -x "$EXTRACTED_PROJECT/scripts/run-swiftpm-package-graph-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/audit-module-stewardship.py" \
  && -x "$EXTRACTED_PROJECT/scripts/run-module-stewardship-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/run-codex-app-server-adapter-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/check-contribution.py" \
  && -x "$EXTRACTED_PROJECT/scripts/create-content-pack.py" \
  && -x "$EXTRACTED_PROJECT/scripts/new-content-pack.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/run-content-pack-scaffold-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/audit-content-pack-locales.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/content-pack-locale-matrix-cli.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/run-content-pack-locale-matrix-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/audit-public-source-secrets.py" \
  && -x "$EXTRACTED_PROJECT/scripts/run-public-source-secret-audit-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/bootstrap-public-git.py" \
  && -x "$EXTRACTED_PROJECT/scripts/prepare-public-code-only.py" \
  && -x "$EXTRACTED_PROJECT/scripts/run-public-git-bootstrap-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/audit-product-boundary.py" \
  && -x "$EXTRACTED_PROJECT/scripts/run-product-boundary-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/run-contributor-check-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/Resources/starter-media.json" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackProjectionEditor.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackArchivePolicy.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackArchiveImporter.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionContentPackImportPanel.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackRecoveryCatalog.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionContentPackRecoverySection.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/audit-content-pack-archive.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/build-content-pack-archive.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/build-content-pack-archive.py" \
  && -f "$EXTRACTED_PROJECT/scripts/content-pack-archive-audit-cli.swift" \
  && -f "$EXTRACTED_PROJECT/scripts/content-pack-archive-fixtures.py" \
  && -x "$EXTRACTED_PROJECT/scripts/run-content-pack-archive-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/check-content-pack-archive-integration.py" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionDisplayCatalog.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionPresentationSurface.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionPlaybackCoordinator.swift" \
	  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionContentSequenceView.swift" \
	  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionMediaPresentation.swift" \
	  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionStatusOverlays.swift" \
	  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionGestureDiscoveryCoordinator.swift" \
	  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionPresentationRuntimeCoordinator.swift" \
	  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionPetFeedbackRuntimeCoordinator.swift" \
	  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionContentLibraryRuntimeCoordinator.swift" \
	  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionPreferenceStore.swift" \
	  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionSettingsBackupProjection.swift" \
	  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionVoiceSelectionRuntimeCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionLifestyleRuntimeCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionLifestyleEventProjection.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionLifestylePresentation.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionContentOperationModels.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionContentOperationReceiptFactory.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionBackupOperationsCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionContentOperationsCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionMicrogameRuntimeCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionExperienceRuntimeCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionWorkdayRuntimeCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionWorkdayApplicationProjection.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionSharedDayRuntimeCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionEventSpool.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionEventIngress.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionEventWatcher.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionFirstSessionRuntimeCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionFirstSessionCoach.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionFirstSessionIntegration.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionAccessibility.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionWorkdayPresentation.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackTriggerContract.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackRuntimeAccessibility.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackPlaybackModels.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackRuntimeCatalog.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackRuntimeSelection.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionContentSequenceRuntimeCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionMediaAccessibilityPresentation.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionEventPresentation.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionEventTriggerRouting.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionRuntimeSupport.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionRuntimeRepairCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionRuntimeReadinessPresentation.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionRelationshipRuntimeCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionRelationshipContentSelection.swift" \
  && -f "$EXTRACTED_PROJECT/scripts/gesture-discovery-coordinator-smoke.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/run-gesture-discovery-coordinator-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/presentation-runtime-coordinator-smoke.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/run-presentation-runtime-coordinator-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/check-microgame-window-policy-integration.py" \
  && -f "$EXTRACTED_PROJECT/scripts/microgame-window-policy-smoke.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/run-microgame-window-policy-smoke.sh" \
	  && -f "$EXTRACTED_PROJECT/scripts/pet-feedback-runtime-coordinator-smoke.swift" \
	  && -x "$EXTRACTED_PROJECT/scripts/run-pet-feedback-runtime-coordinator-smoke.sh" \
	  && -f "$EXTRACTED_PROJECT/scripts/content-library-runtime-coordinator-smoke.swift" \
	  && -x "$EXTRACTED_PROJECT/scripts/run-content-library-runtime-coordinator-smoke.sh" \
	  && -f "$EXTRACTED_PROJECT/scripts/preference-store-smoke.swift" \
	  && -x "$EXTRACTED_PROJECT/scripts/run-preference-store-smoke.sh" \
	  && -f "$EXTRACTED_PROJECT/scripts/settings-backup-projection-smoke.swift" \
	  && -x "$EXTRACTED_PROJECT/scripts/run-settings-backup-projection-smoke.sh" \
	  && -f "$EXTRACTED_PROJECT/scripts/voice-selection-runtime-smoke.swift" \
	  && -x "$EXTRACTED_PROJECT/scripts/run-voice-selection-runtime-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionMicrogamePresentation.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionMicrogameCompletionPresentation.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionTaskCompletionPresentation.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionPetDragPresentation.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionMicrogameCompletionPolicy.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionMicrogameWindowPolicy.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionTaskCompletionPolicy.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionPetDragPolicy.swift" \
  && -f "$EXTRACTED_PROJECT/scripts/lifestyle-runtime-coordinator-smoke.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionPlaybackHealth.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionPlayPaletteLayout.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionLocaleResolutionPolicy.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionProjectionAuthoring.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionPresentationEnvironment.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionWorkdaySignalTrustPolicy.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionContracts/CompanionWorkdayExperiencePolicy.swift" \
  && -f "$EXTRACTED_PROJECT/scripts/apply-content-pack-projection.py" \
  && -f "$EXTRACTED_PROJECT/scripts/apply-content-pack-experience.py" \
  && -x "$EXTRACTED_PROJECT/scripts/author-content-pack-experience.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/run-content-pack-experience-authoring-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/check-projection-authoring-integration.py" \
  && -f "$EXTRACTED_PROJECT/scripts/check-presentation-environment-integration.py" \
  && -f "$EXTRACTED_PROJECT/scripts/check-content-operations-integration.py" \
  && -f "$EXTRACTED_PROJECT/scripts/check-content-pack-store-modularity.py" \
  && -f "$EXTRACTED_PROJECT/scripts/check-content-pack-validator-modularity.py" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackStoreModels.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackStoreDurability.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackStoreLayout.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackActiveRecordRepository.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackStoreLockCoordinator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackStoreRepository.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackManifestFieldValidator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackContributionValidationSupport.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackRightsValidator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackAccessibilityValidator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackFallbackValidator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackContributionValidator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackPackageContentsValidator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackAssetFileValidator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackAssetProjectionValidator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackAssetValidator.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackInstallTransactions.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackPlaybackHealthTransactions.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackStoreSnapshotProjection.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackStoreMaintenanceTransactions.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/CompanionContentLibraryModels.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackVideoDecodeFallback.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackNonVideoMediaProbe.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackVideoMediaProbe.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackMediaProbe.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackMediaCheckpointDecoder.swift" \
  && -f "$EXTRACTED_PROJECT/Sources/CompanionApp/ContentPackMediaQualityProbe.swift" \
  && -f "$EXTRACTED_PROJECT/scripts/content-pack-creator-media-fallback.swift" \
  && -f "$EXTRACTED_PROJECT/scripts/microgame-runtime-coordinator-smoke.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/run-microgame-runtime-coordinator-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/check-experience-runtime-integration.py" \
  && -f "$EXTRACTED_PROJECT/scripts/experience-runtime-coordinator-smoke.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/run-experience-runtime-coordinator-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/workday-runtime-coordinator-smoke.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/run-workday-runtime-coordinator-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/check-shared-day-integration.py" \
  && -f "$EXTRACTED_PROJECT/scripts/shared-day-runtime-coordinator-smoke.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/run-shared-day-runtime-coordinator-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/check-event-spool-integration.py" \
  && -f "$EXTRACTED_PROJECT/scripts/event-spool-smoke.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/run-event-spool-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/check-first-session-integration.py" \
  && -x "$EXTRACTED_PROJECT/scripts/run-first-session-runtime-coordinator-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/check-english-first-use-audit-integration.py" \
  && -f "$EXTRACTED_PROJECT/scripts/english-first-use-visual-audit.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/run-english-first-use-visual-audit.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/run-english-first-use-visual-audit-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/runtime-environment-smoke.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/run-runtime-environment-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/audit-local-runtime-identity.py" \
  && -f "$EXTRACTED_PROJECT/scripts/macos_process_inspection.py" \
  && -f "$EXTRACTED_PROJECT/scripts/run-local-runtime-identity-smoke.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/preview-local.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/local-preview.py" \
  && -f "$EXTRACTED_PROJECT/scripts/local-preview-smoke.py" \
  && -f "$EXTRACTED_PROJECT/scripts/local-preview-sleeper.swift" \
  && -x "$EXTRACTED_PROJECT/scripts/run-local-preview-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/swift-build-cache.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/run-swift-build-cache-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/swift-toolchain-env.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/run-swift-toolchain-env-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/Schemas/local-preview-receipt-v1.schema.json" \
  && -f "$EXTRACTED_PROJECT/scripts/audit-direct-play-runtime.py" \
  && -f "$EXTRACTED_PROJECT/scripts/audit-all-game-rewards.py" \
  && -f "$EXTRACTED_PROJECT/scripts/game_reward_receipt_contract.py" \
  && -f "$EXTRACTED_PROJECT/scripts/run-game-reward-receipt-smoke.py" \
  && -f "$EXTRACTED_PROJECT/scripts/check-game-reward-audit-integration.py" \
  && -x "$EXTRACTED_PROJECT/scripts/check-python-runtime.sh" \
  && -x "$EXTRACTED_PROJECT/scripts/run-python-runtime-smoke.sh" \
  && -f "$EXTRACTED_PROJECT/scripts/direct-play-window-audit.swift" \
  && -f "$EXTRACTED_PROJECT/scripts/catch-game-smoke.swift" \
  && -f "$EXTRACTED_PROJECT/scripts/hide-game-smoke.swift" \
  && -f "$EXTRACTED_PROJECT/scripts/combo-game-smoke.swift" \
  && -f "$EXTRACTED_PROJECT/scripts/heart-trace-smoke.swift" \
  && -f "$EXTRACTED_PROJECT/scripts/rhythm-game-smoke.swift" \
  && -f "$EXTRACTED_PROJECT/scripts/feed-game-smoke.swift" \
  && -f "$EXTRACTED_PROJECT/docs/STARTER-MEDIA-CONTRACT.md" \
  && -f "$EXTRACTED_PROJECT/docs/STARTER-MEDIA-CONTRACT.zh-Hans.md" \
  && -f "$EXTRACTED_PROJECT/docs/CORE-MODULE-BOUNDARY.md" \
  && -f "$EXTRACTED_PROJECT/docs/CORE-MODULE-BOUNDARY.zh-Hans.md" \
  && -f "$EXTRACTED_PROJECT/docs/CODEX-APP-SERVER-ADAPTER.md" \
  && -f "$EXTRACTED_PROJECT/docs/CODEX-APP-SERVER-ADAPTER.zh-Hans.md" \
  && -f "$EXTRACTED_PROJECT/docs/EVENT-SPOOL-SECURITY.md" \
  && -f "$EXTRACTED_PROJECT/docs/EVENT-SPOOL-SECURITY.zh-Hans.md" \
  && -f "$EXTRACTED_PROJECT/docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.md" \
  && -f "$EXTRACTED_PROJECT/docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.zh-Hans.md" \
  && -f "$EXTRACTED_PROJECT/docs/LOCAL-PREVIEW.md" \
  && -f "$EXTRACTED_PROJECT/docs/LOCAL-PREVIEW.zh-Hans.md" \
  && -f "$EXTRACTED_PROJECT/docs/PRODUCT-BOUNDARY.md" \
  && -f "$EXTRACTED_PROJECT/docs/PRODUCT-BOUNDARY.zh-Hans.md" \
  && -f "$EXTRACTED_PROJECT/examples/packs/hello-workday/manifest.json" \
  && -f "$EXTRACTED_PROJECT/.github/workflows/ci.yml" \
  && -f "$EXTRACTED_PROJECT/README.en.md" \
  && -f "$EXTRACTED_PROJECT/GOVERNANCE.zh-Hans.md" ]] \
  || fail "valid source archive lost build or contribution paths"
[[ -f "$EXTRACTED_PROJECT/LICENSE" \
  && -f "$EXTRACTED_PROJECT/LICENSE-SCOPE.md" \
  && -f "$EXTRACTED_PROJECT/PUBLIC-CODE-ONLY.md" ]] \
  || fail "valid source archive lost the owner-approved MIT code license boundary"
grep -Fq 'scripts/heart-trace-smoke.swift' "$EXTRACTED_PROJECT/scripts/doctor.sh" \
  || fail "valid source archive Doctor lost the heart-trace audit entrypoint"
if grep -Fq 'scripts/heart-trace-game-smoke.swift' "$EXTRACTED_PROJECT/scripts/doctor.sh"; then
  fail "valid source archive Doctor retained the invalid heart-trace audit path"
fi
for forbidden in .ai-bridge .build .git dist video-production; do
  [[ ! -e "$EXTRACTED_PROJECT/$forbidden" ]] \
    || fail "valid source archive included forbidden generated/private state"
done
for historical in \
  COMMERCIAL-MASTER-PLAN.md \
  COMMERCIAL-READINESS-AUDIT.md \
  CONTENT-FACTORY-100M.md \
  EXECUTION-ROADMAP.md \
  GITHUB-GROWTH-AND-COMMERCE.md \
  GLOBAL-COMMERCIAL-PLAN.md \
  PAYMENT-DECISION-CN.md \
  PRODUCT-STRATEGY.md \
  UNIT-ECONOMICS-AND-METRICS.md; do
  [[ ! -e "$EXTRACTED_PROJECT/docs/$historical" ]] \
    || fail "valid source archive leaked superseded commercialization research"
done

ditto "$EXTRACTED_PROJECT" "$TAMPER_PARENT/$ARCHIVE_ROOT"
printf '\nsource-package-tamper-fixture\n' \
  >> "$TAMPER_PARENT/$ARCHIVE_ROOT/README.md"
python3 "$PROJECT_DIR/scripts/create-portable-source-zip.py" \
  "$TAMPER_PARENT/$ARCHIVE_ROOT" \
  "$TAMPER_ARCHIVE"
set +e
TAMPER_RECEIPT="$($AUDITOR "$TAMPER_ARCHIVE" --json)"
TAMPER_STATUS=$?
set -e
[[ "$TAMPER_STATUS" -eq 1 ]] \
  || fail "checksum-tampered source archive was accepted"
SOURCE_RECEIPT="$TAMPER_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["code"] == "SOURCE_PACKAGE_CHECKSUM_MISMATCH", receipt
assert receipt["recoveryAction"], receipt
encoded = json.dumps(receipt)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
PY

mkdir -p "$COHERENT_PARENT"
ditto "$EXTRACTED_PROJECT" "$COHERENT_PARENT/$ARCHIVE_ROOT"
printf '\ncoherent-source-package-fingerprint-fixture\n' \
  >> "$COHERENT_PARENT/$ARCHIVE_ROOT/docs/SOURCE-PACKAGE-CONTRACT.md"
(
  cd "$COHERENT_PARENT/$ARCHIVE_ROOT"
  : > SOURCE-SHA256SUMS.txt
  while IFS= read -r -d '' relative_path; do
    relative_path="${relative_path#./}"
    checksum="$(shasum -a 256 "$relative_path" | awk '{ print $1 }')"
    printf '%s  %s\n' "$checksum" "$relative_path" >> SOURCE-SHA256SUMS.txt
  done < <(find . -type f ! -name SOURCE-SHA256SUMS.txt -print0 | LC_ALL=C sort -z)
)
python3 "$PROJECT_DIR/scripts/create-portable-source-zip.py" \
  "$COHERENT_PARENT/$ARCHIVE_ROOT" \
  "$COHERENT_ARCHIVE"
set +e
COHERENT_RECEIPT="$($AUDITOR "$COHERENT_ARCHIVE" --json)"
COHERENT_STATUS=$?
set -e
[[ "$COHERENT_STATUS" -eq 1 ]] \
  || fail "coherently repacked source archive retained a stale package identity"
SOURCE_RECEIPT="$COHERENT_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["code"] == "SOURCE_PACKAGE_FINGERPRINT_MISMATCH", receipt
assert receipt["recoveryAction"], receipt
encoded = json.dumps(receipt)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
PY

mkdir -p "$SECRET_PARENT"
ditto "$EXTRACTED_PROJECT" "$SECRET_PARENT/$ARCHIVE_ROOT"
print -r -- '{"fixture":"not-a-real-credential"}' \
  > "$SECRET_PARENT/$ARCHIVE_ROOT/Sources/credentials.json"
PYTHONDONTWRITEBYTECODE=1 python3 - "$SECRET_PARENT/$ARCHIVE_ROOT" <<'PY'
import hashlib, json, pathlib, sys
root=pathlib.Path(sys.argv[1])
selected=sorted(
    path for path in root.rglob('*')
    if path.is_file() and path.name not in {'SOURCE-PACKAGE.json','SOURCE-SHA256SUMS.txt'}
)
digest=hashlib.sha256()
for path in selected:
    relative=path.relative_to(root).as_posix()
    checksum=hashlib.sha256(path.read_bytes()).hexdigest()
    digest.update(relative.encode())
    digest.update(b'\0')
    digest.update(checksum.encode())
    digest.update(b'\0')
fingerprint=digest.hexdigest()
manifest_path=root/'SOURCE-PACKAGE.json'
manifest=json.loads(manifest_path.read_text())
manifest['sourcePackageFingerprint']=fingerprint
manifest['sourcePackageIdentity']=manifest['buildIdentity']+'.src.'+fingerprint[:12]
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True)+'\n')
inventory=[]
for path in sorted(path for path in root.rglob('*') if path.is_file() and path.name != 'SOURCE-SHA256SUMS.txt'):
    relative=path.relative_to(root).as_posix()
    inventory.append(hashlib.sha256(path.read_bytes()).hexdigest()+'  '+relative)
(root/'SOURCE-SHA256SUMS.txt').write_text('\n'.join(inventory)+'\n')
PY
python3 "$PROJECT_DIR/scripts/create-portable-source-zip.py" \
  "$SECRET_PARENT/$ARCHIVE_ROOT" \
  "$SECRET_ARCHIVE"
set +e
SECRET_RECEIPT="$($AUDITOR "$SECRET_ARCHIVE" --json)"
SECRET_STATUS=$?
set -e
[[ "$SECRET_STATUS" -eq 1 ]] \
  || fail "coherently checksummed credential file was accepted"
SOURCE_RECEIPT="$SECRET_RECEIPT" python3 - <<'PY'
import json, os
receipt=json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["status"] == "FAIL", receipt
assert receipt["code"] == "SOURCE_SECRET_AUDIT_FINDINGS", receipt
assert receipt["recoveryAction"], receipt
encoded=json.dumps(receipt)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
PY

for forbidden_name in secrets.txt .env private-photo.jpg .DS_Store; do
  case_archive="$SMOKE_ROOT/forbidden-${forbidden_name//./_}.zip"
  python3 -c \
    'import sys, zipfile; z=zipfile.ZipFile(sys.argv[1], "w"); z.writestr("extra-source/" + sys.argv[2], "x"); z.close()' \
    "$case_archive" \
    "$forbidden_name"
  set +e
  CASE_RECEIPT="$($AUDITOR "$case_archive" --json)"
  CASE_STATUS=$?
  set -e
  [[ "$CASE_STATUS" -eq 1 ]] \
    || fail "extra source path was accepted: $forbidden_name"
  SOURCE_RECEIPT="$CASE_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["code"] == "SOURCE_PACKAGE_FORBIDDEN_PATH", receipt
encoded = json.dumps(receipt)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
PY
done

COLLISION_ARCHIVE="$SMOKE_ROOT/file-directory-collision.zip"
python3 -c \
  'import stat, sys, zipfile; z=zipfile.ZipFile(sys.argv[1], "w"); z.writestr("collision-source/Sources/Thing", "x"); i=zipfile.ZipInfo("collision-source/Sources/Thing/"); i.create_system=3; i.external_attr=(stat.S_IFDIR | 0o755) << 16; z.writestr(i, b""); z.close()' \
  "$COLLISION_ARCHIVE"
set +e
COLLISION_RECEIPT="$($AUDITOR "$COLLISION_ARCHIVE" --json)"
COLLISION_STATUS=$?
set -e
[[ "$COLLISION_STATUS" -eq 1 ]] \
  || fail "file/directory normalization collision was accepted"
SOURCE_RECEIPT="$COLLISION_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["code"] == "SOURCE_PACKAGE_UNSAFE_ENTRY", receipt
PY

SYMLINK_ARCHIVE="$SMOKE_ROOT/symlink-source.zip"
python3 -c \
  'import stat, sys, zipfile; z=zipfile.ZipFile(sys.argv[1], "w"); i=zipfile.ZipInfo("symlink-source/Sources/link"); i.create_system=3; i.external_attr=(stat.S_IFLNK | 0o777) << 16; z.writestr(i, "../outside"); z.close()' \
  "$SYMLINK_ARCHIVE"
set +e
SYMLINK_RECEIPT="$($AUDITOR "$SYMLINK_ARCHIVE" --json)"
SYMLINK_STATUS=$?
set -e
[[ "$SYMLINK_STATUS" -eq 1 ]] \
  || fail "symbolic-link source entry was accepted"
SOURCE_RECEIPT="$SYMLINK_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["code"] == "SOURCE_PACKAGE_UNSAFE_ENTRY", receipt
PY

python3 -c \
  'import sys, zipfile; z=zipfile.ZipFile(sys.argv[1], "w"); z.writestr("attack-source/../escape", "x"); z.close()' \
  "$UNSAFE_ARCHIVE"
set +e
UNSAFE_RECEIPT="$($AUDITOR "$UNSAFE_ARCHIVE" --json)"
UNSAFE_STATUS=$?
set -e
[[ "$UNSAFE_STATUS" -eq 1 ]] \
  || fail "path-traversal source archive was accepted"
SOURCE_RECEIPT="$UNSAFE_RECEIPT" python3 - <<'PY'
import json, os
receipt = json.loads(os.environ["SOURCE_RECEIPT"])
assert receipt["code"] == "SOURCE_PACKAGE_UNSAFE_ENTRY", receipt
encoded = json.dumps(receipt)
assert "/Users/" not in encoded and "/Volumes/" not in encoded, receipt
PY

SHARED_SWIFT_TMP="$SMOKE_ROOT/shared-swift-tmp"
mkdir -p "$SHARED_SWIFT_TMP"
PYTHON_RUNTIME_SMOKE="$EXTRACTED_PROJECT/scripts/run-python-runtime-smoke.sh"
[[ -x "$PYTHON_RUNTIME_SMOKE" && ! -L "$PYTHON_RUNTIME_SMOKE" ]] \
  || fail "isolated Python runtime smoke is missing before concurrent preflight"
PYTHON_RUNTIME_SMOKE_SHA_BEFORE="$(shasum -a 256 "$PYTHON_RUNTIME_SMOKE" | awk '{ print $1 }')"
TMPDIR="$SHARED_SWIFT_TMP" \
  "$EXTRACTED_PROJECT/scripts/bootstrap-local.sh" \
  --check-only \
  --source-only \
  >"$SMOKE_ROOT/bootstrap-a.log" 2>&1 &
BOOTSTRAP_A_PID=$!
TMPDIR="$SHARED_SWIFT_TMP" \
  "$EXTRACTED_PROJECT/scripts/bootstrap-local.sh" \
  --check-only \
  --source-only \
  >"$SMOKE_ROOT/bootstrap-b.log" 2>&1 &
BOOTSTRAP_B_PID=$!
set +e
wait "$BOOTSTRAP_A_PID"
BOOTSTRAP_A_STATUS=$?
wait "$BOOTSTRAP_B_PID"
BOOTSTRAP_B_STATUS=$?
set -e
[[ "$BOOTSTRAP_A_STATUS" -eq 0 && "$BOOTSTRAP_B_STATUS" -eq 0 ]] \
  || fail "concurrent source preflights interfered with the shared Swift probe cache"
assert_isolated_source_sentinel "concurrent bootstrap postcheck"
[[ -x "$PYTHON_RUNTIME_SMOKE" && ! -L "$PYTHON_RUNTIME_SMOKE" ]] \
  || fail "concurrent source preflights removed the isolated Python runtime smoke"
PYTHON_RUNTIME_SMOKE_SHA_AFTER="$(shasum -a 256 "$PYTHON_RUNTIME_SMOKE" | awk '{ print $1 }')"
[[ "$PYTHON_RUNTIME_SMOKE_SHA_BEFORE" == "$PYTHON_RUNTIME_SMOKE_SHA_AFTER" ]] \
  || fail "concurrent source preflights changed the isolated Python runtime smoke"

(
  cd "$EXTRACTED_PROJECT"
  run_quiet_check bootstrap ./scripts/bootstrap-local.sh --check-only --source-only
  run_quiet_check python-runtime ./scripts/run-python-runtime-smoke.sh
  run_quiet_check public-source-secret-audit python3 scripts/audit-public-source-secrets.py --json
  run_quiet_check public-source-secret-matrix ./scripts/run-public-source-secret-audit-smoke.sh
  run_quiet_check product-boundary python3 scripts/audit-product-boundary.py --scope public --json
  run_quiet_check product-boundary-matrix ./scripts/run-product-boundary-smoke.sh
  run_quiet_check product-boundary-schema python3 -m json.tool Schemas/product-boundary-receipt-v1.schema.json
  run_quiet_check public-git-bootstrap ./scripts/run-public-git-bootstrap-smoke.sh
  run_quiet_check public-git-bootstrap-schema python3 -m json.tool Schemas/public-git-bootstrap-receipt-v1.schema.json
  run_quiet_check public-source-secret-schema python3 -m json.tool Schemas/public-source-secret-audit-v1.schema.json
  run_quiet_check low-impact ./scripts/run-first-use-low-impact-audit.sh --zero-authorization
  run_quiet_check public-doc-parity python3 scripts/check-public-doc-parity.py
  run_quiet_check localization-parity python3 scripts/check-localization-parity.py
  run_quiet_check accessibility-localization python3 scripts/audit-accessibility-localization.py --json
  run_quiet_check accessibility-localization-matrix ./scripts/run-accessibility-localization-smoke.sh
  run_quiet_check error-code-registry python3 scripts/check-error-code-contract.py
  run_quiet_check content-pack-scaffold ./scripts/run-content-pack-scaffold-smoke.sh
  run_quiet_check content-pack-locale-matrix ./scripts/run-content-pack-locale-matrix-smoke.sh
  run_quiet_check content-pack-locale-schema python3 -m json.tool Schemas/content-pack-locale-matrix-v1.schema.json
  run_quiet_check english-first-use-integration python3 scripts/check-english-first-use-audit-integration.py
  run_quiet_check english-first-use-matrix ./scripts/run-english-first-use-visual-audit-smoke.sh
  run_quiet_check english-first-use-schema python3 -m json.tool Schemas/english-first-use-visual-audit-v1.schema.json
  run_quiet_check app-server-schema python3 -m json.tool Schemas/codex-app-server-turn-events-v1.schema.json
  run_quiet_check projection-authoring python3 scripts/check-projection-authoring-integration.py
  run_quiet_check presentation-environment python3 scripts/check-presentation-environment-integration.py
  run_quiet_check lifestyle-memory python3 scripts/check-lifestyle-memory-integration.py
  run_quiet_check content-operations python3 scripts/check-content-operations-integration.py
  run_quiet_check content-pack-store-modularity python3 scripts/check-content-pack-store-modularity.py
  run_quiet_check content-pack-validator-modularity python3 scripts/check-content-pack-validator-modularity.py
  run_quiet_check presentation-runtime python3 scripts/check-presentation-runtime-integration.py
  run_quiet_check microgame-window-policy-integration python3 scripts/check-microgame-window-policy-integration.py
  run_quiet_check pet-feedback-runtime-integration python3 scripts/check-pet-feedback-runtime-integration.py
  run_quiet_check content-library-runtime-integration python3 scripts/check-content-library-runtime-integration.py
  run_quiet_check preference-store-integration python3 scripts/check-preference-store-integration.py
  run_quiet_check settings-backup-projection-integration python3 scripts/check-settings-backup-projection-integration.py
  run_quiet_check voice-selection-runtime-integration python3 scripts/check-voice-selection-runtime-integration.py
  run_quiet_check runtime-support python3 scripts/check-runtime-support-integration.py
  run_quiet_check relationship-runtime-integration python3 scripts/check-relationship-runtime-integration.py
  run_quiet_check runtime-identity ./scripts/run-local-runtime-identity-smoke.sh
  run_quiet_check local-preview-contract ./scripts/run-local-preview-smoke.sh
  run_quiet_check swift-build-cache ./scripts/run-swift-build-cache-smoke.sh
  run_quiet_check swift-toolchain-cache ./scripts/run-swift-toolchain-env-smoke.sh
  run_quiet_check local-preview-schema python3 -m json.tool Schemas/local-preview-receipt-v1.schema.json
  run_quiet_check direct-play python3 scripts/check-direct-play-integration.py
  run_quiet_check game-reward-audit-integration python3 scripts/check-game-reward-audit-integration.py
  run_quiet_check game-reward-receipt-matrix python3 scripts/run-game-reward-receipt-smoke.py
  run_quiet_check game-reward-receipt-schema python3 -m json.tool Schemas/all-game-rewards-v1.schema.json
  run_quiet_check event-spool-integration python3 scripts/check-event-spool-integration.py
  run_quiet_check shared-workday python3 scripts/check-workday-integration.py
  run_quiet_check shared-day-integration python3 scripts/check-shared-day-integration.py
  run_quiet_check microgame-integration python3 scripts/check-microgame-integration.py
  run_quiet_check microgame-runtime ./scripts/run-microgame-runtime-coordinator-smoke.sh
  run_quiet_check experience-runtime-integration python3 scripts/check-experience-runtime-integration.py
  run_quiet_check experience-runtime ./scripts/run-experience-runtime-coordinator-smoke.sh
  run_quiet_check workday-runtime ./scripts/run-workday-runtime-coordinator-smoke.sh
  run_quiet_check shared-day-runtime ./scripts/run-shared-day-runtime-coordinator-smoke.sh
  run_quiet_check event-spool-security ./scripts/run-event-spool-smoke.sh
  run_quiet_check first-session-integration python3 scripts/check-first-session-integration.py
  run_quiet_check first-session-runtime ./scripts/run-first-session-runtime-coordinator-smoke.sh
  run_quiet_check window-visibility python3 scripts/check-window-visibility-integration.py
  run_quiet_check runtime-repair ./scripts/run-runtime-repair-smoke.sh
  run_quiet_check relationship-runtime ./scripts/run-relationship-runtime-coordinator-smoke.sh
  run_quiet_check gesture-discovery-runtime ./scripts/run-gesture-discovery-coordinator-smoke.sh
  run_quiet_check presentation-runtime-coordinator ./scripts/run-presentation-runtime-coordinator-smoke.sh
  run_quiet_check microgame-window-policy ./scripts/run-microgame-window-policy-smoke.sh
  run_quiet_check pet-feedback-runtime-coordinator ./scripts/run-pet-feedback-runtime-coordinator-smoke.sh
  run_quiet_check content-library-runtime-coordinator ./scripts/run-content-library-runtime-coordinator-smoke.sh
  run_quiet_check preference-store ./scripts/run-preference-store-smoke.sh
  run_quiet_check settings-backup-projection ./scripts/run-settings-backup-projection-smoke.sh
  run_quiet_check voice-selection-runtime ./scripts/run-voice-selection-runtime-smoke.sh
  run_quiet_check core-boundary-audit python3 scripts/audit-core-module-boundaries.py --json
  run_quiet_check swift-compiler-boundary python3 scripts/audit-swift-compiler-boundaries.py --json
  run_quiet_check swift-compiler-boundary-matrix ./scripts/run-swift-compiler-boundary-smoke.sh
  run_quiet_check module-stewardship-audit python3 scripts/audit-module-stewardship.py --audit --json
  run_quiet_check module-stewardship-matrix ./scripts/run-module-stewardship-smoke.sh
  run_quiet_check swiftpm-package-graph python3 scripts/audit-swiftpm-package-graph.py --json
  run_quiet_check swiftpm-package-graph-matrix ./scripts/run-swiftpm-package-graph-smoke.sh
  run_quiet_check contributor-quick ./scripts/check-contribution.py --profile quick --json
  run_quiet_check core-boundary-matrix ./scripts/run-core-module-boundary-smoke.sh
  run_quiet_check contributor-receipt-schema python3 -m json.tool Schemas/contributor-check-receipt-v1.schema.json
  run_quiet_check source-schema python3 -m json.tool Schemas/source-package-v1.schema.json
  run_quiet_check projection-schema python3 -m json.tool Schemas/projection-authoring-receipt-v1.schema.json
  run_quiet_check experience-authoring-schema python3 -m json.tool Schemas/experience-authoring-receipt-v1.schema.json
  run_quiet_check core-baseline python3 -m json.tool Schemas/core-module-boundary-baseline-v1.json
  run_quiet_check module-stewardship-schema python3 -m json.tool Schemas/module-stewardship-v1.schema.json
  run_quiet_check starter-schema python3 -m json.tool Schemas/starter-media-v1.schema.json
  run_quiet_check starter-manifest python3 scripts/refresh-starter-media-manifest.py --check
  run_quiet_check starter-audit python3 scripts/audit-starter-media.py --json
  run_quiet_check starter-matrix ./scripts/run-starter-media-contract-smoke.sh
  run_playback_soak_check ./scripts/run-playback-media-soak-smoke.sh
  run_quiet_check release-state ./scripts/run-release-readiness-smoke.sh
)

(
  cd "$EXTRACTED_PROJECT"
  source scripts/swift-toolchain-env.sh
  run_quiet_check app-build swift build --disable-sandbox --product ChengyinCompanion
  run_quiet_check core-contracts swift run --disable-sandbox CompanionContractChecks
  run_quiet_check app-server-adapter ./scripts/run-codex-app-server-adapter-smoke.sh
  run_quiet_check example-pack ./scripts/validate-content-pack.sh examples/packs/hello-workday --json
  run_quiet_check content-pack-v2 ./scripts/run-content-pack-v2-contract-matrix.sh
  run_quiet_check content-pack-archive ./scripts/run-content-pack-archive-smoke.sh
  run_quiet_check content-pack-archive-integration python3 scripts/check-content-pack-archive-integration.py
  run_quiet_check projection-editor ./scripts/run-content-pack-projection-editor-smoke.sh
  run_quiet_check projection-apply ./scripts/run-projection-receipt-apply-smoke.sh
  run_quiet_check experience-authoring ./scripts/run-content-pack-experience-authoring-smoke.sh
  run_quiet_check canonical-experience-pack python3 scripts/check-example-experience-pack.py
  run_quiet_check canonical-experience-pack-matrix ./scripts/run-example-experience-pack-smoke.sh
)

SOURCE_SHA_AFTER="$({
  for source_path in "${KEY_SOURCES[@]}"; do
    print -r -- "$source_path"
    shasum -a 256 "$PROJECT_DIR/$source_path" | awk '{ print $1 }'
  done
} | shasum -a 256 | awk '{ print $1 }')"
[[ "$SOURCE_SHA_BEFORE" == "$SOURCE_SHA_AFTER" ]] \
  || fail "source-package validation modified authoritative project scripts"

ISOLATED_CHECK_COUNT="$(grep -Ec '^[[:space:]]+run_(quiet_check|playback_soak_check) ' "$0")"
if [[ "$(<"$PLAYBACK_SOAK_STATUS_FILE")" == "PENDING" ]]; then
  print "Portable source package smoke: PASS_WITH_PENDING ($ISOLATED_CHECK_COUNT/$ISOLATED_CHECK_COUNT executable checks + archive threat matrix; playback AVFoundation proof PENDING)"
else
  print "Portable source package smoke: PASS ($ISOLATED_CHECK_COUNT/$ISOLATED_CHECK_COUNT isolated checks + archive threat matrix)"
fi
print "Release state: NOT_PUBLIC_RELEASE_READY"
