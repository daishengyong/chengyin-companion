#!/usr/bin/env python3
"""Audit a Chengyin source-preview ZIP without extracting untrusted entries."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import pathlib
import plistlib
import re
import stat
import sys
import unicodedata
import zipfile

# The archive auditor dynamically loads the sibling credential policy.  Keep
# that read-only operation from creating a source-tree __pycache__ directory,
# even when callers forget to export PYTHONDONTWRITEBYTECODE.
sys.dont_write_bytecode = True


MAX_ARCHIVE_BYTES = 1_000_000_000
MAX_FILES = 4096
MAX_FILE_BYTES = 512 * 1024 * 1024
MAX_TOTAL_BYTES = 2 * 1024 * 1024 * 1024
MAX_MANIFEST_BYTES = 128 * 1024
MAX_CHECKSUM_BYTES = 2 * 1024 * 1024

ROOT_FILES = [
    ".gitignore",
    "AGENTS.md",
    "CODE_OF_CONDUCT.md",
    "CODE_OF_CONDUCT.zh-Hans.md",
    "CONTRIBUTING.md",
    "CONTRIBUTING.en.md",
    "GOVERNANCE.md",
    "GOVERNANCE.zh-Hans.md",
    "Info.plist",
    "LICENSE",
    "LICENSE-SCOPE.md",
    "PUBLIC-CODE-ONLY.md",
    "Package.swift",
    "README.md",
    "README.en.md",
    "ROADMAP.md",
    "ROADMAP.zh-Hans.md",
    "SECURITY.md",
    "SECURITY.en.md",
    "SUPPORT.md",
    "SUPPORT.zh-Hans.md",
]
ROOT_DIRECTORIES = [
    ".github",
    "Schemas",
    "Skills",
    "Sources",
    "Tests",
    "Tools",
    "community",
    "docs",
    "examples",
    "packaging",
    "scripts",
]
INCLUDED_PATHS = ROOT_FILES + ROOT_DIRECTORIES + ["release"]
EXCLUDED_PATHS = [
    ".agents",
    ".ai-bridge",
    ".build",
    ".codex",
    ".git",
    "dist",
    "video-production",
    "release/generated-artifacts",
]
REQUIRED_FILES = set(
    ROOT_FILES
    + [
        ".github/workflows/ci.yml",
        "Schemas/community-pack-index-v1.schema.json",
        "Schemas/codex-app-server-turn-events-v1.schema.json",
        "Schemas/contributor-check-receipt-v1.schema.json",
        "Schemas/all-game-rewards-v1.schema.json",
        "Schemas/content-pack-v2.schema.json",
        "Schemas/core-module-boundary-baseline-v1.json",
        "Schemas/error-codes-v1.json",
        "Schemas/english-first-use-visual-audit-v1.schema.json",
        "Schemas/local-preview-receipt-v1.schema.json",
        "Schemas/experience-authoring-receipt-v1.schema.json",
        "Schemas/content-pack-scaffold-receipt-v1.schema.json",
        "Schemas/content-pack-locale-matrix-v1.schema.json",
        "Schemas/public-source-secret-audit-v1.schema.json",
        "Schemas/module-stewardship-v1.schema.json",
        "Schemas/projection-authoring-receipt-v1.schema.json",
        "Schemas/release-gates-v1.schema.json",
        "Schemas/source-package-v1.schema.json",
        "Schemas/public-git-bootstrap-receipt-v1.schema.json",
        "Schemas/product-boundary-receipt-v1.schema.json",
        "Schemas/starter-media-v1.schema.json",
        "Skills/chengyin-companion/SKILL.md",
        "Sources/CompanionApp/CompanionApp.swift",
        "Sources/CompanionApp/CompanionVideoPlayer.swift",
        "Sources/CompanionApp/CompanionPlaybackCoordinator.swift",
        "Sources/CompanionApp/CompanionContentSequenceView.swift",
        "Sources/CompanionApp/CompanionMediaPresentation.swift",
        "Sources/CompanionApp/CompanionStatusOverlays.swift",
        "Sources/CompanionApp/CompanionGestureDiscoveryCoordinator.swift",
        "Sources/CompanionApp/CompanionPresentationRuntimeCoordinator.swift",
        "Sources/CompanionApp/CompanionPetFeedbackRuntimeCoordinator.swift",
        "Sources/CompanionApp/CompanionContentLibraryRuntimeCoordinator.swift",
        "Sources/CompanionApp/CompanionPreferenceStore.swift",
        "Sources/CompanionApp/CompanionSettingsBackupProjection.swift",
        "Sources/CompanionApp/CompanionVoiceSelectionRuntimeCoordinator.swift",
        "Sources/CompanionApp/CompanionLifestyleRuntimeCoordinator.swift",
        "Sources/CompanionApp/CompanionLifestyleEventProjection.swift",
        "Sources/CompanionApp/CompanionLifestylePresentation.swift",
        "Sources/CompanionApp/CompanionContentOperationModels.swift",
        "Sources/CompanionApp/CompanionContentOperationReceiptFactory.swift",
        "Sources/CompanionApp/CompanionBackupOperationsCoordinator.swift",
        "Sources/CompanionApp/CompanionContentOperationsCoordinator.swift",
        "Sources/CompanionApp/ContentPackRecoveryCatalog.swift",
        "Sources/CompanionApp/CompanionContentPackRecoverySection.swift",
        "Sources/CompanionApp/CompanionMicrogamePresentation.swift",
        "Sources/CompanionApp/CompanionMicrogameCompletionPresentation.swift",
        "Sources/CompanionApp/CompanionTaskCompletionPresentation.swift",
        "Sources/CompanionApp/CompanionPetDragPresentation.swift",
        "Sources/CompanionApp/CompanionMicrogameRuntimeCoordinator.swift",
        "Sources/CompanionApp/CompanionExperienceRuntimeCoordinator.swift",
        "Sources/CompanionApp/CompanionWorkdayRuntimeCoordinator.swift",
        "Sources/CompanionApp/CompanionWorkdayApplicationProjection.swift",
        "Sources/CompanionApp/CompanionSharedDayRuntimeCoordinator.swift",
        "Sources/CompanionApp/CompanionFirstSessionRuntimeCoordinator.swift",
        "Sources/CompanionApp/CompanionFirstSessionCoach.swift",
        "Sources/CompanionApp/CompanionFirstSessionIntegration.swift",
        "Sources/CompanionApp/CompanionRuntimeEnvironment.swift",
        "Sources/CompanionApp/ContentPackProjectionEditor.swift",
        "Sources/CompanionApp/CompanionDisplayCatalog.swift",
        "Sources/CompanionApp/CompanionPresentationPreferences.swift",
        "Sources/CompanionApp/CompanionPresentationSurface.swift",
        "Sources/CompanionApp/CompanionWindowSettingsSection.swift",
        "Sources/CompanionApp/CompanionPetInteractionSurface.swift",
        "Sources/CompanionApp/ContentPackManifest.swift",
        "Sources/CompanionApp/ContentPackManifestFieldValidator.swift",
        "Sources/CompanionApp/ContentPackContributionValidationSupport.swift",
        "Sources/CompanionApp/ContentPackRightsValidator.swift",
        "Sources/CompanionApp/ContentPackAccessibilityValidator.swift",
        "Sources/CompanionApp/ContentPackFallbackValidator.swift",
        "Sources/CompanionApp/ContentPackContributionValidator.swift",
        "Sources/CompanionApp/ContentPackPackageContentsValidator.swift",
        "Sources/CompanionApp/ContentPackAssetFileValidator.swift",
        "Sources/CompanionApp/ContentPackAssetProjectionValidator.swift",
        "Sources/CompanionApp/ContentPackAssetValidator.swift",
        "Sources/CompanionApp/ContentPackArchivePolicy.swift",
        "Sources/CompanionApp/ContentPackArchiveImporter.swift",
        "Sources/CompanionApp/ContentPackVideoDecodeFallback.swift",
        "Sources/CompanionApp/ContentPackNonVideoMediaProbe.swift",
        "Sources/CompanionApp/ContentPackVideoMediaProbe.swift",
        "Sources/CompanionApp/ContentPackMediaProbe.swift",
        "Sources/CompanionApp/ContentPackMediaCheckpointDecoder.swift",
        "Sources/CompanionApp/ContentPackMediaQualityProbe.swift",
        "Sources/CompanionApp/CompanionContentPackImportPanel.swift",
        "Sources/CompanionApp/ContentPackTriggerContract.swift",
        "Sources/CompanionApp/ContentPackRuntimeAccessibility.swift",
        "Sources/CompanionApp/ContentPackPlaybackModels.swift",
        "Sources/CompanionApp/ContentPackRuntimeCatalog.swift",
        "Sources/CompanionApp/ContentPackRuntimeSelection.swift",
        "Sources/CompanionApp/CompanionContentSequenceRuntimeCoordinator.swift",
        "Sources/CompanionApp/CompanionMediaAccessibilityPresentation.swift",
        "Sources/CompanionApp/CompanionFailureReceipt.swift",
        "Sources/CompanionApp/SemanticVersion.swift",
        "Sources/CompanionApp/CompanionEventSpool.swift",
        "Sources/CompanionApp/CompanionEventIngress.swift",
        "Sources/CompanionApp/CompanionEventWatcher.swift",
        "Sources/CompanionApp/CompanionEventBridgeRepair.swift",
        "Sources/CompanionApp/CompanionRuntimeSupport.swift",
        "Sources/CompanionApp/CompanionRuntimeRepairCoordinator.swift",
        "Sources/CompanionApp/CompanionRuntimeReadinessPresentation.swift",
        "Sources/CompanionApp/CompanionRelationshipRuntimeCoordinator.swift",
        "Sources/CompanionApp/CompanionRelationshipContentSelection.swift",
        "Sources/CompanionApp/ContentPackStoreLayout.swift",
        "Sources/CompanionApp/ContentPackActiveRecordRepository.swift",
        "Sources/CompanionApp/ContentPackStoreLockCoordinator.swift",
        "Sources/CompanionApp/ContentPackStoreRepository.swift",
        "Sources/CompanionApp/ContentPackInstallPreflight.swift",
        "Sources/CompanionApp/ContentPackInstallTransactions.swift",
        "Sources/CompanionApp/ContentPackRecoveryTransactions.swift",
        "Sources/CompanionApp/ContentPackPlaybackHealthTransactions.swift",
        "Sources/CompanionApp/ContentPackStoreSnapshotProjection.swift",
        "Sources/CompanionApp/ContentPackStoreMaintenanceTransactions.swift",
        "Sources/CompanionApp/ContentPackStoreModels.swift",
        "Sources/CompanionApp/ContentPackStoreDurability.swift",
        "Sources/CompanionApp/CompanionContentLibraryModels.swift",
        "Sources/CompanionApp/CompanionSupportDiagnosticsSection.swift",
        "Sources/CompanionApp/CompanionAccessibility.swift",
        "Sources/CompanionApp/CompanionWorkdayAdapter.swift",
        "Sources/CompanionApp/CompanionWorkdayPresentation.swift",
        "Sources/CompanionApp/CompanionEventPresentation.swift",
        "Sources/CompanionApp/CompanionEventTriggerRouting.swift",
        "scripts/lifestyle-runtime-coordinator-smoke.swift",
        "Sources/CompanionApp/CompanionWindowVisibilityKeeper.swift",
        "Sources/CompanionContracts/CompanionEvent.swift",
        "Sources/CompanionContracts/CodexAppServerMapper.swift",
        "Sources/CompanionContracts/CompanionPresentationProjection.swift",
        "Sources/CompanionContracts/CompanionPresentationSession.swift",
        "Sources/CompanionContracts/CompanionPresentationLifecycle.swift",
        "Sources/CompanionContracts/CompanionFirstSession.swift",
        "Sources/CompanionContracts/CompanionPlaybackHealth.swift",
        "Sources/CompanionContracts/CompanionPlayPaletteLayout.swift",
        "Sources/CompanionContracts/CompanionLocaleResolutionPolicy.swift",
        "Sources/CompanionContracts/CompanionRuntimeReadiness.swift",
        "Sources/CompanionContracts/CompanionWorkdayState.swift",
        "Sources/CompanionContracts/CompanionWorkDirector.swift",
        "Sources/CompanionContracts/CompanionWorkdaySignalTrustPolicy.swift",
        "Sources/CompanionContracts/CompanionWorkdayExperiencePolicy.swift",
        "Sources/CompanionContracts/CompanionTaskCompletionPolicy.swift",
        "Sources/CompanionContracts/CompanionPetDragPolicy.swift",
        "Sources/CompanionContracts/CompanionMicrogameCompletionPolicy.swift",
        "Sources/CompanionContracts/CompanionMicrogameSession.swift",
        "Sources/CompanionContracts/CompanionMicrogameWindowPolicy.swift",
        "Sources/CompanionContracts/CompanionProjectionAuthoring.swift",
        "Sources/CompanionContracts/CompanionPresentationEnvironment.swift",
        "Tests/CompanionContractsTests/main.swift",
        "Tools/CompanionEventEmitter/main.swift",
        "community/index.json",
        "community/module-stewardship.json",
        "docs/CONTRIBUTOR-ARCHITECTURE.md",
        "docs/CONTENT-PACK-THREAT-MODEL.md",
        "docs/SOURCE-PACKAGE-CONTRACT.md",
        "docs/SOURCE-PACKAGE-CONTRACT.zh-Hans.md",
        "docs/STARTER-MEDIA-CONTRACT.md",
        "docs/STARTER-MEDIA-CONTRACT.zh-Hans.md",
        "docs/CORE-MODULE-BOUNDARY.md",
        "docs/CORE-MODULE-BOUNDARY.zh-Hans.md",
        "docs/MODULE-STEWARDSHIP.md",
        "docs/MODULE-STEWARDSHIP.zh-Hans.md",
        "docs/CODEX-APP-SERVER-ADAPTER.md",
        "docs/CODEX-APP-SERVER-ADAPTER.zh-Hans.md",
        "docs/EVENT-SPOOL-SECURITY.md",
        "docs/EVENT-SPOOL-SECURITY.zh-Hans.md",
        "docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.md",
        "docs/ENGLISH-FIRST-USE-VISUAL-AUDIT.zh-Hans.md",
        "docs/LOCAL-PREVIEW.md",
        "docs/LOCAL-PREVIEW.zh-Hans.md",
        "docs/PRODUCT-BOUNDARY.md",
        "docs/PRODUCT-BOUNDARY.zh-Hans.md",
        "examples/packs/hello-workday/manifest.json",
        "examples/packs/generate-hello-workday-media.sh",
        "packaging/portable/START-HERE.md",
        "release/README.md",
        "release/release-gates.json",
        "scripts/audit-portable-source.py",
        "scripts/bootstrap-public-git.py",
        "scripts/prepare-public-code-only.py",
        "scripts/audit-public-source-secrets.py",
        "scripts/audit-product-boundary.py",
        "scripts/run-public-source-secret-audit-smoke.sh",
        "scripts/check-example-experience-pack.py",
        "scripts/run-example-experience-pack-smoke.sh",
        "scripts/audit-accessibility-localization.py",
        "scripts/audit-core-module-boundaries.py",
        "scripts/audit-swift-compiler-boundaries.py",
        "scripts/audit-module-stewardship.py",
        "scripts/audit-swiftpm-package-graph.py",
        "scripts/audit-starter-media.py",
        "scripts/audit-local-runtime-identity.py",
        "scripts/macos_process_inspection.py",
        "scripts/local-preview.py",
        "scripts/preview-local.sh",
        "scripts/local-preview-smoke.py",
        "scripts/local-preview-sleeper.swift",
        "scripts/run-local-preview-smoke.sh",
        "scripts/swift-build-cache.sh",
        "scripts/run-swift-build-cache-smoke.sh",
        "scripts/swift-toolchain-env.sh",
        "scripts/run-swift-toolchain-env-smoke.sh",
        "scripts/audit-direct-play-runtime.py",
        "scripts/audit-all-game-rewards.py",
        "scripts/game_reward_receipt_contract.py",
        "scripts/run-game-reward-receipt-smoke.py",
        "scripts/check-game-reward-audit-integration.py",
        "scripts/apply-content-pack-projection.py",
        "scripts/apply-content-pack-experience.py",
        "scripts/create-content-pack.py",
        "scripts/new-content-pack.sh",
        "scripts/run-content-pack-scaffold-smoke.sh",
        "scripts/audit-content-pack-locales.sh",
        "scripts/content-pack-locale-matrix-cli.swift",
        "scripts/run-content-pack-locale-matrix-smoke.sh",
        "scripts/author-content-pack-experience.sh",
        "scripts/bootstrap-local.sh",
        "scripts/build-app.sh",
        "scripts/build-creator-tool.sh",
        "scripts/content-pack-creator-media-fallback.swift",
        "scripts/audit-content-pack-archive.sh",
        "scripts/build-content-pack-archive.py",
        "scripts/build-content-pack-archive.sh",
        "scripts/content-pack-archive-audit-cli.swift",
        "scripts/content-pack-archive-fixtures.py",
        "scripts/build-portable-source.sh",
        "scripts/check-error-code-contract.py",
        "scripts/check-contribution.py",
        "scripts/check-python-runtime.sh",
        "scripts/check-presentation-runtime-integration.py",
        "scripts/check-pet-feedback-runtime-integration.py",
        "scripts/check-content-library-runtime-integration.py",
        "scripts/check-preference-store-integration.py",
        "scripts/check-settings-backup-projection-integration.py",
        "scripts/check-voice-selection-runtime-integration.py",
        "scripts/check-runtime-support-integration.py",
        "scripts/check-relationship-runtime-integration.py",
        "scripts/check-content-pack-store-modularity.py",
        "scripts/check-content-pack-validator-modularity.py",
        "scripts/check-event-spool-integration.py",
        "scripts/check-workday-integration.py",
        "scripts/check-first-session-integration.py",
        "scripts/check-english-first-use-audit-integration.py",
        "scripts/check-microgame-integration.py",
        "scripts/check-microgame-window-policy-integration.py",
        "scripts/microgame-runtime-coordinator-smoke.swift",
        "scripts/run-microgame-runtime-coordinator-smoke.sh",
        "scripts/microgame-window-policy-smoke.swift",
        "scripts/run-microgame-window-policy-smoke.sh",
        "scripts/check-experience-runtime-integration.py",
        "scripts/workday-runtime-coordinator-smoke.swift",
        "scripts/run-workday-runtime-coordinator-smoke.sh",
        "scripts/check-shared-day-integration.py",
        "scripts/shared-day-runtime-coordinator-smoke.swift",
        "scripts/run-shared-day-runtime-coordinator-smoke.sh",
        "scripts/event-spool-smoke.swift",
        "scripts/run-event-spool-smoke.sh",
        "scripts/first-session-runtime-coordinator-smoke.swift",
        "scripts/run-first-session-runtime-coordinator-smoke.sh",
        "scripts/runtime-environment-smoke.swift",
        "scripts/run-runtime-environment-smoke.sh",
        "scripts/english-first-use-visual-audit.swift",
        "scripts/run-english-first-use-visual-audit.sh",
        "scripts/run-english-first-use-visual-audit-smoke.sh",
        "scripts/experience-runtime-coordinator-smoke.swift",
        "scripts/run-experience-runtime-coordinator-smoke.sh",
        "scripts/check-window-visibility-integration.py",
        "scripts/runtime-repair-smoke.swift",
        "scripts/run-runtime-repair-smoke.sh",
        "scripts/run-relationship-runtime-coordinator-smoke.sh",
        "scripts/relationship-runtime-coordinator-smoke.swift",
        "scripts/gesture-discovery-coordinator-smoke.swift",
        "scripts/run-gesture-discovery-coordinator-smoke.sh",
        "scripts/presentation-runtime-coordinator-smoke.swift",
        "scripts/run-presentation-runtime-coordinator-smoke.sh",
        "scripts/pet-feedback-runtime-coordinator-smoke.swift",
        "scripts/run-pet-feedback-runtime-coordinator-smoke.sh",
        "scripts/content-library-runtime-coordinator-smoke.swift",
        "scripts/run-content-library-runtime-coordinator-smoke.sh",
        "scripts/preference-store-smoke.swift",
        "scripts/run-preference-store-smoke.sh",
        "scripts/settings-backup-projection-smoke.swift",
        "scripts/run-settings-backup-projection-smoke.sh",
        "scripts/voice-selection-runtime-smoke.swift",
        "scripts/run-voice-selection-runtime-smoke.sh",
        "scripts/run-local-runtime-identity-smoke.sh",
        "scripts/run-python-runtime-smoke.sh",
        "scripts/direct-play-window-audit.swift",
        "scripts/catch-game-smoke.swift",
        "scripts/hide-game-smoke.swift",
        "scripts/combo-game-smoke.swift",
        "scripts/heart-trace-smoke.swift",
        "scripts/rhythm-game-smoke.swift",
        "scripts/feed-game-smoke.swift",
        "scripts/playback-media-soak.swift",
        "scripts/run-playback-media-soak.sh",
        "scripts/run-playback-media-soak-smoke.sh",
        "scripts/check-projection-authoring-integration.py",
        "scripts/check-presentation-environment-integration.py",
        "scripts/check-content-operations-integration.py",
        "scripts/check-content-pack-archive-integration.py",
        "scripts/check-public-doc-parity.py",
        "scripts/edit-content-pack-projection.sh",
        "scripts/create-portable-source-zip.py",
        "scripts/doctor.sh",
        "scripts/install-local-app.sh",
        "scripts/run-content-pack-v2-contract-matrix.sh",
        "scripts/run-contributor-check-smoke.sh",
        "scripts/run-content-pack-projection-editor-smoke.sh",
        "scripts/run-core-module-boundary-smoke.sh",
        "scripts/run-swift-compiler-boundary-smoke.sh",
        "scripts/run-swiftpm-package-graph-smoke.sh",
        "scripts/run-module-stewardship-smoke.sh",
        "scripts/run-codex-app-server-adapter-smoke.sh",
        "scripts/run-accessibility-localization-smoke.sh",
        "scripts/run-portable-source-smoke.sh",
        "scripts/run-public-git-bootstrap-smoke.sh",
        "scripts/run-product-boundary-smoke.sh",
        "scripts/run-projection-receipt-apply-smoke.sh",
        "scripts/run-content-pack-experience-authoring-smoke.sh",
        "scripts/run-content-pack-archive-smoke.sh",
        "scripts/run-starter-media-contract-smoke.sh",
        "scripts/refresh-starter-media-manifest.py",
        "Sources/CompanionApp/Resources/starter-media.json",
        "SOURCE-PACKAGE.json",
        "SOURCE-SHA256SUMS.txt",
    ]
)
FORBIDDEN_COMPONENTS = {
    ".agents",
    ".ai-bridge",
    ".build",
    ".codex",
    ".git",
    "__MACOSX",
    "__pycache__",
    ".DS_Store",
    "dist",
    "video-production",
}
MANIFEST_KEYS = {
    "schemaVersion",
    "artifactKind",
    "product",
    "archiveRoot",
    "appVersion",
    "appBuild",
    "appSourceFingerprint",
    "buildIdentity",
    "sourcePackageFingerprint",
    "sourcePackageIdentity",
    "platform",
    "completenessProfile",
    "integrityScope",
    "includedPaths",
    "excludedPaths",
    "checksumsFile",
    "releaseGateRegistry",
    "releaseGates",
}
PLATFORM_KEYS = {"os", "minimumVersion", "architectures"}
RELEASE_GATE_KEYS = {
    "mediaRights",
    "finalLicense",
    "developerID",
    "notarization",
    "ownerReleaseApproval",
    "publicRelease",
}


class AuditFailure(Exception):
    def __init__(self, code: str, message: str, action: str):
        super().__init__(message)
        self.code = code
        self.message = message
        self.action = action


def fail(code: str, message: str, action: str) -> None:
    raise AuditFailure(code, message, action)


def safe_json(data: bytes, *, limit: int, label: str) -> object:
    if len(data) > limit:
        fail(
            "SOURCE_PACKAGE_CONTRACT_INVALID",
            f"The {label} exceeds its bounded size.",
            "Download or build a fresh source package, then rerun the audit.",
        )
    try:
        return json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        fail(
            "SOURCE_PACKAGE_CONTRACT_INVALID",
            f"The {label} is not valid UTF-8 JSON.",
            "Download or build a fresh source package, then rerun the audit.",
        )


def read_member(archive: zipfile.ZipFile, info: zipfile.ZipInfo, limit: int) -> bytes:
    if info.file_size > limit:
        fail(
            "SOURCE_PACKAGE_CONTRACT_INVALID",
            "A source-package contract file exceeds its bounded size.",
            "Download or build a fresh source package, then rerun the audit.",
        )
    with archive.open(info, "r") as stream:
        return stream.read(limit + 1)


def validate_entry_name(name: str) -> tuple[str, ...]:
    if not name or "\\" in name or name.startswith("/") or "\x00" in name:
        fail(
            "SOURCE_PACKAGE_UNSAFE_ENTRY",
            "The source archive contains an unsafe path.",
            "Discard the archive and obtain a fresh package from a trusted source.",
        )
    trimmed = name[:-1] if name.endswith("/") else name
    parts = tuple(trimmed.split("/"))
    if not parts or any(part in {"", ".", ".."} for part in parts):
        fail(
            "SOURCE_PACKAGE_UNSAFE_ENTRY",
            "The source archive contains a non-normalized path.",
            "Discard the archive and obtain a fresh package from a trusted source.",
        )
    return parts


def relative_path_is_allowed(relative: str, *, is_directory: bool) -> bool:
    parts = relative.split("/")
    if not parts:
        return False
    first = parts[0]
    if any(
        component.startswith(".")
        and not (
            index == 0 and component in {".github", ".gitignore"}
        )
        for index, component in enumerate(parts)
    ):
        return False
    if first in ROOT_FILES:
        return not is_directory and len(parts) == 1
    if first in ROOT_DIRECTORIES:
        return is_directory or len(parts) >= 2
    if first == "release":
        if is_directory:
            return relative == "release"
        return relative in {"release/README.md", "release/release-gates.json"}
    if is_directory:
        return False
    return relative in {"SOURCE-PACKAGE.json", "SOURCE-SHA256SUMS.txt"}


def parse_checksum_file(data: bytes) -> dict[str, str]:
    if len(data) > MAX_CHECKSUM_BYTES:
        fail(
            "SOURCE_PACKAGE_CONTRACT_INVALID",
            "The source checksum inventory exceeds its bounded size.",
            "Download or build a fresh source package, then rerun the audit.",
        )
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        fail(
            "SOURCE_PACKAGE_CONTRACT_INVALID",
            "The source checksum inventory is not UTF-8 text.",
            "Download or build a fresh source package, then rerun the audit.",
        )
    checksums: dict[str, str] = {}
    for line in text.splitlines():
        pieces = line.split("  ", 1)
        if len(pieces) != 2 or not re.fullmatch(r"[0-9a-f]{64}", pieces[0]):
            fail(
                "SOURCE_PACKAGE_CONTRACT_INVALID",
                "The source checksum inventory contains an invalid record.",
                "Download or build a fresh source package, then rerun the audit.",
            )
        relative_path = pieces[1]
        validate_entry_name(relative_path)
        if relative_path in checksums:
            fail(
                "SOURCE_PACKAGE_CONTRACT_INVALID",
                "The source checksum inventory contains a duplicate path.",
                "Download or build a fresh source package, then rerun the audit.",
            )
        checksums[relative_path] = pieces[0]
    if not checksums:
        fail(
            "SOURCE_PACKAGE_CONTRACT_INVALID",
            "The source checksum inventory is empty.",
            "Download or build a fresh source package, then rerun the audit.",
        )
    return checksums


def validate_manifest(manifest: object, archive_root: str) -> dict[str, object]:
    if not isinstance(manifest, dict) or set(manifest) != MANIFEST_KEYS:
        fail(
            "SOURCE_PACKAGE_CONTRACT_INVALID",
            "The source-package manifest has missing or unknown fields.",
            "Rebuild with the current source-package tool, then rerun the audit.",
        )
    if (
        manifest.get("schemaVersion") != 1
        or manifest.get("artifactKind") != "source-preview"
        or manifest.get("product") != "Chengyin Companion"
        or manifest.get("archiveRoot") != archive_root
        or manifest.get("completenessProfile") != "clone-build-contribute-v1"
        or manifest.get("integrityScope") != "internal-consistency-not-authenticity"
        or manifest.get("includedPaths") != INCLUDED_PATHS
        or manifest.get("excludedPaths") != EXCLUDED_PATHS
        or manifest.get("checksumsFile") != "SOURCE-SHA256SUMS.txt"
        or manifest.get("releaseGateRegistry") != "release/release-gates.json"
    ):
        fail(
            "SOURCE_PACKAGE_CONTRACT_INVALID",
            "The source-package manifest does not match the clone/build/contribute contract.",
            "Rebuild with the current source-package tool, then rerun the audit.",
        )
    version = manifest.get("appVersion")
    build = manifest.get("appBuild")
    fingerprint = manifest.get("appSourceFingerprint")
    identity = manifest.get("buildIdentity")
    source_package_fingerprint = manifest.get("sourcePackageFingerprint")
    source_package_identity = manifest.get("sourcePackageIdentity")
    if (
        not isinstance(version, str)
        or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version)
        or not isinstance(build, str)
        or not re.fullmatch(r"[0-9]+", build)
        or not isinstance(fingerprint, str)
        or not re.fullmatch(r"[0-9a-f]{64}", fingerprint)
        or identity != f"{version}+{build}.{fingerprint[:12]}"
        or not isinstance(source_package_fingerprint, str)
        or not re.fullmatch(r"[0-9a-f]{64}", source_package_fingerprint)
        or source_package_identity
        != f"{identity}.src.{source_package_fingerprint[:12]}"
    ):
        fail(
            "SOURCE_PACKAGE_IDENTITY_MISMATCH",
            "The declared source build identity is invalid.",
            "Rebuild from a complete checkout, then rerun the audit.",
        )
    platform = manifest.get("platform")
    if (
        not isinstance(platform, dict)
        or set(platform) != PLATFORM_KEYS
        or platform.get("os") != "macOS"
        or platform.get("minimumVersion") != "14.0"
        or platform.get("architectures") != ["arm64"]
    ):
        fail(
            "SOURCE_PACKAGE_CONTRACT_INVALID",
            "The source-package platform contract is invalid.",
            "Rebuild with the current source-package tool, then rerun the audit.",
        )
    release_gates = manifest.get("releaseGates")
    if (
        not isinstance(release_gates, dict)
        or set(release_gates) != RELEASE_GATE_KEYS
        or release_gates.get("publicRelease") != "not-ready"
    ):
        fail(
            "SOURCE_PACKAGE_RELEASE_STATE_MISMATCH",
            "The source package does not preserve the explicit preview-only release state.",
            "Restore the owner gate registry and rebuild; do not publish this artifact.",
        )
    return manifest


def compute_app_source_fingerprint(
    archive: zipfile.ZipFile,
    entries: dict[str, zipfile.ZipInfo],
) -> str:
    fixed = {
        "Package.swift",
        "Info.plist",
        "scripts/build-app.sh",
        "scripts/swift-build-cache.sh",
        "scripts/swift-toolchain-env.sh",
        "scripts/macos_process_inspection.py",
        "scripts/install-local-app.sh",
        "scripts/app-bundle-common.sh",
    }
    prefixes = (
        "Sources/CompanionApp/",
        "Sources/CompanionContracts/",
        "Tools/CompanionEventEmitter/",
    )
    selected = sorted(
        relative
        for relative in entries
        if relative in fixed or relative.startswith(prefixes)
    )
    digest = hashlib.sha256()
    for relative in selected:
        file_digest = hashlib.sha256()
        with archive.open(entries[relative], "r") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                file_digest.update(chunk)
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(file_digest.hexdigest().encode("ascii"))
        digest.update(b"\0")
    return digest.hexdigest()


def compute_source_package_fingerprint(
    archive: zipfile.ZipFile,
    entries: dict[str, zipfile.ZipInfo],
) -> str:
    generated_identity_files = {"SOURCE-PACKAGE.json", "SOURCE-SHA256SUMS.txt"}
    selected = sorted(set(entries) - generated_identity_files)
    digest = hashlib.sha256()
    for relative in selected:
        file_digest = hashlib.sha256()
        with archive.open(entries[relative], "r") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                file_digest.update(chunk)
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(file_digest.hexdigest().encode("ascii"))
        digest.update(b"\0")
    return digest.hexdigest()


def load_public_source_secret_policy():
    policy_path = pathlib.Path(__file__).with_name(
        "audit-public-source-secrets.py"
    )
    try:
        specification = importlib.util.spec_from_file_location(
            "chengyin_public_source_secret_audit",
            policy_path,
        )
        if specification is None or specification.loader is None:
            raise ImportError("secret audit specification unavailable")
        module = importlib.util.module_from_spec(specification)
        sys.modules[specification.name] = module
        specification.loader.exec_module(module)
        return module
    except Exception:
        fail(
            "SOURCE_SECRET_AUDIT_UNEXPECTED_ERROR",
            "The trusted public-source secret policy could not be loaded.",
            "Restore both source audit scripts from a trusted checkout, then retry.",
        )


def audit_embedded_public_source_secrets(
    archive: zipfile.ZipFile,
    entries: dict[str, zipfile.ZipInfo],
) -> dict[str, object]:
    policy = load_public_source_secret_policy()
    text_files_scanned = 0
    binary_files_skipped = 0
    bytes_scanned = 0
    finding_count = 0
    for relative, info in sorted(entries.items()):
        path = pathlib.PurePosixPath(relative)
        if policy.is_high_risk_name(path):
            finding_count += 1
            continue
        if path.suffix.casefold() in policy.BINARY_SUFFIXES:
            binary_files_skipped += 1
            continue
        if info.file_size > policy.MAX_TEXT_FILE_BYTES:
            fail(
                "SOURCE_SECRET_AUDIT_RESOURCE_LIMIT",
                "A non-media packaged source file exceeds the bounded secret-scan size.",
                "Remove generated payloads from public source roots, rebuild and retry.",
            )
        payload = read_member(archive, info, policy.MAX_TEXT_FILE_BYTES)
        bytes_scanned += len(payload)
        if bytes_scanned > policy.MAX_TEXT_BYTES:
            fail(
                "SOURCE_SECRET_AUDIT_RESOURCE_LIMIT",
                "The packaged public source exceeds the bounded secret-scan size.",
                "Remove generated files from public source roots, rebuild and retry.",
            )
        try:
            text = payload.decode("utf-8")
        except UnicodeDecodeError:
            fail(
                "SOURCE_SECRET_AUDIT_UNREADABLE_FILE",
                "A non-media packaged source file is not UTF-8 text.",
                "Move binary payloads to declared media locations or encode source as UTF-8, then retry.",
            )
        text_files_scanned += 1
        finding_count += len(policy.scan_text(relative, text))
    if finding_count:
        fail(
            "SOURCE_SECRET_AUDIT_FINDINGS",
            "The packaged public source contains credential material that must be removed.",
            "Revoke any real credential, remove it from source and history, rebuild and rerun the audit.",
        )
    return {
        "contract": policy.CONTRACT,
        "status": "PASS",
        "textFilesScanned": text_files_scanned,
        "binaryFilesSkipped": binary_files_skipped,
        "bytesScanned": bytes_scanned,
        "findingCount": 0,
        "environmentValuesRead": False,
        "contentExcerptsIncluded": False,
    }


def load_product_boundary_policy():
    policy_path = pathlib.Path(__file__).with_name("audit-product-boundary.py")
    try:
        specification = importlib.util.spec_from_file_location(
            "chengyin_product_boundary_audit",
            policy_path,
        )
        if specification is None or specification.loader is None:
            raise ImportError("product boundary specification unavailable")
        module = importlib.util.module_from_spec(specification)
        sys.modules[specification.name] = module
        specification.loader.exec_module(module)
        return module
    except Exception:
        fail(
            "PRODUCT_BOUNDARY_UNEXPECTED_ERROR",
            "The trusted product-boundary policy could not be loaded.",
            "Restore both source audit scripts from a trusted checkout, then retry.",
        )


def audit_embedded_product_boundary(
    archive: zipfile.ZipFile,
    entries: dict[str, zipfile.ZipInfo],
) -> dict[str, object]:
    policy = load_product_boundary_policy()
    runtime_files = 0
    public_files = 0
    findings = []
    total_bytes = 0
    for relative, info in sorted(entries.items()):
        runtime_source = (
            relative in {"Package.swift", "Info.plist"}
            or relative.startswith("Sources/") and relative.endswith(".swift")
        )
        public_document = (
            relative in policy.PUBLIC_ENTRY_DOCUMENTS
            or relative.startswith("docs/") and relative.endswith(".md")
        )
        if not runtime_source and not public_document:
            continue
        if info.file_size > policy.MAX_FILE_BYTES:
            fail(
                "PRODUCT_BOUNDARY_RESOURCE_LIMIT",
                "A packaged product-boundary file exceeds the bounded scan size.",
                "Remove generated payloads from public source, rebuild and retry.",
            )
        payload = read_member(archive, info, policy.MAX_FILE_BYTES)
        total_bytes += len(payload)
        if total_bytes > policy.MAX_TOTAL_BYTES:
            fail(
                "PRODUCT_BOUNDARY_RESOURCE_LIMIT",
                "The packaged product-boundary text exceeds the bounded aggregate size.",
                "Remove generated payloads from public source, rebuild and retry.",
            )
        try:
            text = payload.decode("utf-8")
        except UnicodeDecodeError:
            fail(
                "PRODUCT_BOUNDARY_UNSAFE_PATH",
                "A packaged product-boundary file is not UTF-8 text.",
                "Restore reviewed UTF-8 source files, rebuild and retry.",
            )
        if runtime_source:
            runtime_files += 1
            findings.extend(policy.scan_runtime(relative, text))
        if public_document:
            public_files += 1
            findings.extend(policy.scan_public_document(relative, text))

    runtime_findings = [
        finding for finding in findings
        if finding.category != "historical-research"
    ]
    if runtime_findings:
        fail(
            "PRODUCT_BOUNDARY_FORBIDDEN_RUNTIME",
            "Packaged runtime source contains a forbidden product integration.",
            "Remove the payment, forced-account, advertising or automatic-sharing integration, rebuild and retry.",
        )
    if findings:
        fail(
            "PRODUCT_BOUNDARY_PUBLIC_DOC_LEAK",
            "Packaged public source contains superseded commercialization research or a reference to it.",
            "Move historical research to the private working-copy archive, update public links, rebuild and retry.",
        )
    return {
        "contract": policy.CONTRACT,
        "status": "PASS",
        "scope": "public",
        "runtimeFilesScanned": runtime_files,
        "publicFilesScanned": public_files,
        "forbiddenFindingCount": 0,
        "historicalResearchState": "excluded",
        "networkRequired": False,
        "environmentValuesRead": False,
        "applicationsDirectoryModified": False,
        "contentExcerptsIncluded": False,
    }


def audit(archive_path: pathlib.Path) -> dict[str, object]:
    if (
        not archive_path.is_file()
        or archive_path.is_symlink()
        or archive_path.stat().st_size > MAX_ARCHIVE_BYTES
    ):
        fail(
            "SOURCE_PACKAGE_INVALID_ARCHIVE",
            "The selected source archive is missing, unsafe or too large.",
            "Choose a regular Chengyin source-preview ZIP and retry."
        )
    try:
        archive = zipfile.ZipFile(archive_path, "r")
    except (OSError, zipfile.BadZipFile):
        fail(
            "SOURCE_PACKAGE_INVALID_ARCHIVE",
            "The selected source archive cannot be opened as a ZIP.",
            "Download or build a fresh source package, then retry."
        )

    with archive:
        infos = archive.infolist()
        file_infos = [info for info in infos if not info.is_dir()]
        if not file_infos or len(file_infos) > MAX_FILES:
            fail(
                "SOURCE_PACKAGE_INVALID_ARCHIVE",
                "The source archive has an invalid number of files.",
                "Download or build a fresh source package, then retry."
            )
        roots: set[str] = set()
        seen_names: set[str] = set()
        canonical_names: set[str] = set()
        parsed: list[tuple[zipfile.ZipInfo, tuple[str, ...]]] = []
        total_bytes = 0
        for info in infos:
            parts = validate_entry_name(info.filename)
            roots.add(parts[0])
            mode = (info.external_attr >> 16) & 0o170000
            if mode == stat.S_IFLNK:
                fail(
                    "SOURCE_PACKAGE_UNSAFE_ENTRY",
                    "The source archive contains a symbolic link.",
                    "Discard the archive and obtain a fresh package from a trusted source."
                )
            if info.filename in seen_names:
                fail(
                    "SOURCE_PACKAGE_UNSAFE_ENTRY",
                    "The source archive contains a duplicate path.",
                    "Discard the archive and obtain a fresh package from a trusted source."
                )
            seen_names.add(info.filename)
            canonical = unicodedata.normalize("NFC", "/".join(parts)).casefold()
            if canonical in canonical_names:
                fail(
                    "SOURCE_PACKAGE_UNSAFE_ENTRY",
                    "The source archive contains a case or Unicode path collision.",
                    "Discard the archive and obtain a fresh package from a trusted source."
                )
            canonical_names.add(canonical)
            if any(component in FORBIDDEN_COMPONENTS for component in parts):
                fail(
                    "SOURCE_PACKAGE_FORBIDDEN_PATH",
                    "The source archive contains a forbidden generated or private path.",
                    "Rebuild from the public source allowlist, then rerun the audit."
                )
            parsed.append((info, parts))
            if info.is_dir():
                continue
            if info.file_size > MAX_FILE_BYTES:
                fail(
                    "SOURCE_PACKAGE_INVALID_ARCHIVE",
                    "A source archive entry exceeds the per-file limit.",
                    "Download or build a fresh source package, then retry."
                )
            total_bytes += info.file_size
            if total_bytes > MAX_TOTAL_BYTES:
                fail(
                    "SOURCE_PACKAGE_INVALID_ARCHIVE",
                    "The source archive exceeds the unpacked-size limit.",
                    "Download or build a fresh source package, then retry."
                )
            if (
                info.file_size > 16 * 1024 * 1024
                and info.compress_size > 0
                and info.file_size / info.compress_size > 200
            ):
                fail(
                    "SOURCE_PACKAGE_INVALID_ARCHIVE",
                    "A source archive entry has an unsafe compression ratio.",
                    "Discard the archive and obtain a fresh package from a trusted source."
                )
        if len(roots) != 1:
            fail(
                "SOURCE_PACKAGE_UNSAFE_ENTRY",
                "The source archive must have exactly one top-level directory.",
                "Rebuild with the current source-package tool, then retry."
            )
        archive_root = next(iter(roots))
        if not re.fullmatch(r"[A-Za-z0-9._-]+-source", archive_root):
            fail(
                "SOURCE_PACKAGE_UNSAFE_ENTRY",
                "The source archive root is unsafe or not a source package.",
                "Choose a Chengyin source-preview ZIP and retry."
            )
        entries: dict[str, zipfile.ZipInfo] = {}
        for info, parts in parsed:
            if parts[0] != archive_root:
                fail(
                    "SOURCE_PACKAGE_UNSAFE_ENTRY",
                    "The source archive contains an entry outside its package root.",
                    "Discard the archive and obtain a fresh package from a trusted source."
                )
            if len(parts) == 1 and info.is_dir():
                continue
            if len(parts) < 2:
                fail(
                    "SOURCE_PACKAGE_UNSAFE_ENTRY",
                    "The source archive contains an entry outside its package root.",
                    "Discard the archive and obtain a fresh package from a trusted source."
                )
            relative = "/".join(parts[1:])
            if not relative_path_is_allowed(relative, is_directory=info.is_dir()):
                fail(
                    "SOURCE_PACKAGE_FORBIDDEN_PATH",
                    "The source archive contains a path outside the declared source allowlist.",
                    "Rebuild from the public source allowlist, then rerun the audit."
                )
            if info.is_dir():
                continue
            if relative.startswith("release/generated-artifacts/"):
                fail(
                    "SOURCE_PACKAGE_FORBIDDEN_PATH",
                    "The source archive contains generated release artifacts.",
                    "Rebuild from the public source allowlist, then rerun the audit."
                )
            if relative.endswith(".pyc") or relative.endswith("/.DS_Store"):
                fail(
                    "SOURCE_PACKAGE_FORBIDDEN_PATH",
                    "The source archive contains generated cache metadata.",
                    "Rebuild from the public source allowlist, then rerun the audit."
                )
            entries[relative] = info

        missing = sorted(REQUIRED_FILES - set(entries))
        if missing:
            fail(
                "SOURCE_PACKAGE_REQUIRED_PATH_MISSING",
                f"The source archive is incomplete; required path missing: {missing[0]}",
                "Download or build a complete source package, then rerun the audit."
            )

        manifest_data = read_member(
            archive, entries["SOURCE-PACKAGE.json"], MAX_MANIFEST_BYTES
        )
        manifest = validate_manifest(
            safe_json(manifest_data, limit=MAX_MANIFEST_BYTES, label="source-package manifest"),
            archive_root,
        )
        checksum_data = read_member(
            archive, entries["SOURCE-SHA256SUMS.txt"], MAX_CHECKSUM_BYTES
        )
        checksums = parse_checksum_file(checksum_data)
        expected_checksum_paths = set(entries) - {"SOURCE-SHA256SUMS.txt"}
        if set(checksums) != expected_checksum_paths:
            fail(
                "SOURCE_PACKAGE_CHECKSUM_MISMATCH",
                "The source checksum inventory does not cover exactly the packaged files.",
                "Discard the archive and build or download a fresh source package."
            )
        for relative, expected_hash in checksums.items():
            actual = hashlib.sha256()
            with archive.open(entries[relative], "r") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    actual.update(chunk)
            if actual.hexdigest() != expected_hash:
                fail(
                    "SOURCE_PACKAGE_CHECKSUM_MISMATCH",
                    "A packaged source file does not match the checksum inventory.",
                    "Discard the archive and build or download a fresh source package."
                )

        product_boundary = audit_embedded_product_boundary(archive, entries)
        secret_audit = audit_embedded_public_source_secrets(archive, entries)

        try:
            info_plist = plistlib.loads(archive.read(entries["Info.plist"]))
        except (plistlib.InvalidFileException, ValueError):
            fail(
                "SOURCE_PACKAGE_IDENTITY_MISMATCH",
                "The packaged application metadata is invalid.",
                "Rebuild from a complete checkout, then rerun the audit."
            )
        if (
            info_plist.get("CFBundleShortVersionString") != manifest["appVersion"]
            or str(info_plist.get("CFBundleVersion")) != manifest["appBuild"]
            or info_plist.get("LSMinimumSystemVersion") != "14.0"
        ):
            fail(
                "SOURCE_PACKAGE_IDENTITY_MISMATCH",
                "The source manifest and application metadata do not match.",
                "Rebuild from a complete checkout, then rerun the audit."
            )

        computed_fingerprint = compute_app_source_fingerprint(archive, entries)
        if computed_fingerprint != manifest["appSourceFingerprint"]:
            fail(
                "SOURCE_PACKAGE_IDENTITY_MISMATCH",
                "The packaged runtime sources do not match the declared source identity.",
                "Discard the archive and rebuild from a stable checkout."
            )

        computed_package_fingerprint = compute_source_package_fingerprint(
            archive, entries
        )
        if computed_package_fingerprint != manifest["sourcePackageFingerprint"]:
            fail(
                "SOURCE_PACKAGE_FINGERPRINT_MISMATCH",
                "The packaged public source set does not match its declared package identity.",
                "Discard the archive and rebuild it from a stable trusted checkout."
            )

        gate_data = safe_json(
            archive.read(entries["release/release-gates.json"]),
            limit=MAX_MANIFEST_BYTES,
            label="release-gate registry",
        )
        if not isinstance(gate_data, dict):
            fail(
                "SOURCE_PACKAGE_RELEASE_STATE_MISMATCH",
                "The packaged release-gate registry is invalid.",
                "Restore the owner gate registry and rebuild; do not publish this artifact."
            )
        declared_gates = manifest["releaseGates"]
        gate_mapping = {
            "mediaRights": "mediaRights",
            "finalLicense": "finalLicense",
            "developerID": "developerID",
            "notarization": "notarization",
            "ownerReleaseApproval": "ownerReleaseApproval",
        }
        for manifest_key, registry_key in gate_mapping.items():
            registry_value = gate_data.get(registry_key)
            if (
                not isinstance(registry_value, dict)
                or registry_value.get("status") != declared_gates.get(manifest_key)
            ):
                fail(
                    "SOURCE_PACKAGE_RELEASE_STATE_MISMATCH",
                    "The source manifest and owner release gates do not match.",
                    "Restore the owner gate registry and rebuild; do not publish this artifact."
                )

        return {
            "status": "PASS",
            "contract": "clone-build-contribute-v1",
            "archiveRoot": archive_root,
            "fileCount": len(entries),
            "unpackedBytes": total_bytes,
            "buildIdentity": manifest["buildIdentity"],
            "sourcePackageFingerprint": manifest["sourcePackageFingerprint"],
            "sourcePackageIdentity": manifest["sourcePackageIdentity"],
            "productBoundary": product_boundary,
            "secretAudit": secret_audit,
            "releaseState": "NOT_PUBLIC_RELEASE_READY",
        }


def emit_failure(error: AuditFailure, json_mode: bool) -> int:
    if json_mode:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "code": error.code,
                    "message": error.message,
                    "recoveryAction": error.action,
                },
                ensure_ascii=False,
                sort_keys=True,
            )
        )
    else:
        print(f"FAIL  [{error.code}] {error.message}", file=sys.stderr)
        print(f"ACTION  {error.action}", file=sys.stderr)
    return 1


def main(argv: list[str]) -> int:
    json_mode = False
    values: list[str] = []
    for argument in argv:
        if argument == "--json":
            json_mode = True
        elif argument in {"--help", "-h"}:
            print("Usage: ./scripts/audit-portable-source.py <source.zip> [--json]")
            return 0
        elif argument.startswith("-"):
            return emit_failure(
                AuditFailure(
                    "SOURCE_PACKAGE_INVALID_ARGUMENT",
                    "The source-package auditor received an unknown option.",
                    "Run scripts/audit-portable-source.py --help, correct the command, then retry."
                ),
                json_mode,
            )
        else:
            values.append(argument)
    if len(values) != 1:
        return emit_failure(
            AuditFailure(
                "SOURCE_PACKAGE_INVALID_ARGUMENT",
                "Exactly one source archive is required.",
                "Provide one Chengyin source-preview ZIP, then retry."
            ),
            json_mode,
        )
    try:
        receipt = audit(pathlib.Path(values[0]))
    except AuditFailure as error:
        return emit_failure(error, json_mode)
    except Exception:
        return emit_failure(
            AuditFailure(
                "SOURCE_PACKAGE_UNEXPECTED_ERROR",
                "The source-package audit stopped at a privacy-safe fallback boundary.",
                "Retry once; if it repeats, rebuild or download a fresh source package."
            ),
            json_mode,
        )
    if json_mode:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
    else:
        print(
            "Source package audit: PASS "
            f"({receipt['fileCount']} files, {receipt['buildIdentity']})"
        )
        print("Release state: NOT_PUBLIC_RELEASE_READY")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
