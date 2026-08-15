#!/usr/bin/env python3
"""Audit Chengyin's local-first Core/App module boundary without network access."""

from __future__ import annotations

import argparse
import json
import pathlib
import plistlib
import re
import sys


DEFAULT_ROOT = pathlib.Path(__file__).resolve().parent.parent
CORE_RELATIVE = pathlib.Path("Sources/CompanionContracts")
APP_RELATIVE = pathlib.Path("Sources/CompanionApp")
REQUIRED_CORE_POLICIES = (
    "CompanionAttentionBudget.swift",
    "CompanionChemistryInteractionDirector.swift",
    "CompanionExperienceDirector.swift",
    "CompanionFirstSession.swift",
    "CompanionLifestyleMemory.swift",
    "CompanionLifestyleScheduler.swift",
    "CompanionLocaleResolutionPolicy.swift",
    "CompanionMicrogameCompletionPolicy.swift",
    "CompanionMicrogameSession.swift",
    "CompanionMicrogameWindowPolicy.swift",
    "CompanionPetDragPolicy.swift",
    "CompanionPerformancePolicy.swift",
    "CompanionPlayPaletteLayout.swift",
    "CompanionPlaybackHealth.swift",
    "CompanionPresentationEnvironment.swift",
    "CompanionPresentationLifecycle.swift",
    "CompanionPresentationProjection.swift",
    "CompanionPresentationSession.swift",
    "CompanionRuntimeReadiness.swift",
    "CompanionTaskCompletionPolicy.swift",
    "CompanionUserPresentationPolicy.swift",
    "CompanionWindowPolicy.swift",
    "CompanionWorkDirector.swift",
    "CompanionWorkdayExperiencePolicy.swift",
    "CompanionWorkdaySignalTrustPolicy.swift",
)
LIFESTYLE_PUBLIC_TYPES = (
    "CompanionLifestyleReminderKind",
    "CompanionLifestyleReminderOccurrence",
    "CompanionLifestyleQuietHours",
    "CompanionLifestyleActivityState",
    "CompanionLifestyleSchedulerContext",
    "CompanionLifestyleDeferReason",
    "CompanionLifestyleSilenceReason",
    "CompanionLifestyleSchedulerDecision",
    "CompanionLifestyleSchedulerPolicy",
    "CompanionLifestyleScheduler",
)
LIFESTYLE_MEMORY_PUBLIC_TYPES = (
    "CompanionLifestyleMemoryValidationError",
    "CompanionLifestyleMemoryRecoverySource",
    "CompanionLifestyleMemoryLoadResult",
    "CompanionLifestyleMemoryV1",
    "CompanionLifestyleMemoryCodec",
    "CompanionLifestyleMemoryStore",
)
WORKDAY_PUBLIC_TYPES = (
    "CompanionWorkdayStateValidationError",
    "CompanionWorkdayStateRecoverySource",
    "CompanionWorkdayStateLoadResult",
    "CompanionWorkdayStateV1",
    "CompanionWorkdayStateCodec",
    "CompanionWorkdayStateStore",
)
WORKDAY_SIGNAL_TRUST_PUBLIC_TYPES = (
    "CompanionWorkdaySignalOrigin",
    "CompanionWorkdaySignalSourcePolicy",
    "CompanionWorkdaySignalTrustPolicy",
)
WORKDAY_EXPERIENCE_PUBLIC_TYPES = (
    "CompanionWorkdayVisualIntent",
    "CompanionWorkdayMoodIntent",
    "CompanionWorkdayStatusIntent",
    "CompanionWorkdayEventIntent",
    "CompanionWorkdayContentCue",
    "CompanionWorkdayMilestone",
    "CompanionWorkdayRelationshipReward",
    "CompanionWorkdayPresentationContext",
    "CompanionWorkdayPresentationPlan",
    "CompanionWorkdayExperiencePolicy",
)
TASK_COMPLETION_PUBLIC_TYPES = (
    "CompanionCompletionReplyGesture",
    "CompanionTaskCompletionRewardBeat",
    "CompanionTaskCompletionCopyIntent",
    "CompanionTaskCompletionCelebrationPlan",
    "CompanionCompletionReplyPlan",
    "CompanionTaskCompletionPolicy",
)
PET_DRAG_PUBLIC_TYPES = (
    "CompanionPetDragFeedback",
    "CompanionPetDragInput",
    "CompanionPetDragPosePlan",
    "CompanionPetDragPlan",
    "CompanionPetDragPolicy",
)
CHEMISTRY_PUBLIC_TYPES = (
    "CompanionDirectedInteraction",
    "CompanionDaypart",
    "CompanionInteractionMood",
    "CompanionDirectedMomentKind",
    "CompanionMomentRelationshipBoundary",
    "CompanionDirectedPetMoment",
    "CompanionMomentCandidateTier",
    "CompanionMomentCandidate",
    "CompanionChemistryInteractionContext",
    "CompanionChemistrySelection",
    "CompanionChemistryInteractionDirector",
)
USER_PRESENTATION_PUBLIC_TYPES = (
    "CompanionUserPresentationIntent",
    "CompanionUserPresentationPlan",
    "CompanionUserPresentationPolicy",
)
PRESENTATION_SESSION_PUBLIC_TYPES = (
    "CompanionPresentationReturnOwner",
    "CompanionPresentationSession",
)
PRESENTATION_LIFECYCLE_PUBLIC_TYPES = (
    "CompanionPresentationContentReturnPolicy",
    "CompanionPresentationDirective",
    "CompanionPresentationLifecycle",
)
PLAY_PALETTE_LAYOUT_PUBLIC_TYPES = (
    "CompanionPlayPaletteLayoutPlan",
    "CompanionPlayPaletteLayout",
)
LOCALE_RESOLUTION_PUBLIC_TYPES = (
    "CompanionLocaleResolutionPolicy",
)
FIRST_SESSION_PUBLIC_TYPES = (
    "CompanionFirstSessionPreference",
    "CompanionFirstSessionLaunchDisposition",
    "CompanionFirstSessionLaunchPolicy",
    "CompanionFirstSessionStep",
    "CompanionFirstSessionInput",
    "CompanionFirstSessionEffect",
    "CompanionFirstSessionTransition",
    "CompanionFirstSessionJourney",
)
PLAYBACK_HEALTH_PUBLIC_TYPES = (
    "CompanionPlaybackTerminalReason",
    "CompanionPlaybackFirstFrameStatus",
    "CompanionPlaybackAttemptToken",
    "CompanionPlaybackHealthSnapshot",
    "CompanionPlaybackHealthAccumulator",
)
RUNTIME_READINESS_PUBLIC_TYPES = (
    "CompanionRuntimeReadinessComponent",
    "CompanionRuntimeReadinessLevel",
    "CompanionRuntimeRecoveryAction",
    "CompanionRuntimeReadinessFacts",
    "CompanionRuntimeReadinessCheck",
    "CompanionRuntimeReadiness",
)
RUNTIME_READINESS_REQUIRED_FUNCTIONS = (
    "safeRecoveryActions",
    "hasManualAttention",
)
PRESENTATION_PROJECTION_PUBLIC_TYPES = (
    "CompanionMediaCropAnchor",
    "CompanionMediaFocalKeyframe",
    "CompanionMediaFocalTrack",
    "CompanionMediaSafeArea",
    "CompanionPresentationProjection",
)
PROJECTION_AUTHORING_PUBLIC_TYPES = (
    "CompanionProjectionAuthoringError",
    "CompanionProjectionAuthoringReceipt",
)
PRESENTATION_ENVIRONMENT_PUBLIC_TYPES = (
    "CompanionPresentationSurfacePlan",
    "CompanionPresentationSurfacePolicy",
    "CompanionDisplayDescriptor",
    "CompanionDisplayResolution",
    "CompanionDisplaySelection",
    "CompanionDisplaySelectionPolicy",
)
PRESENTATION_SETTINGS_PUBLIC_TYPES = (
    "CompanionPresentationAppearance",
    "CompanionDisplayTargetMode",
    "CompanionDisplayTarget",
)
MICROGAME_PUBLIC_TYPES = (
    "CompanionMicrogameKind",
    "CompanionMicrogameGesture",
    "CompanionMicrogameInputOutcome",
    "CompanionNormalizedPoint",
    "CompanionMicrogameSession",
)
MICROGAME_COMPLETION_PUBLIC_TYPES = (
    "CompanionMicrogameCompletionMood",
    "CompanionMicrogameRewardBeat",
    "CompanionMicrogameRelationshipReward",
    "CompanionMicrogameCompletionPlan",
    "CompanionMicrogameCompletionPolicy",
)
MICROGAME_WINDOW_PUBLIC_TYPES = (
    "CompanionMicrogameWindowPlacement",
    "CompanionMicrogameWindowPolicy",
)
ALLOWED_CORE_IMPORTS = {"Foundation", "CoreGraphics"}
FORBIDDEN_CORE_TOKENS = (
    "URLSession",
    "NSWorkspace",
    "AVPlayer",
    "AVFoundation",
    "SwiftUI",
    "AppKit",
    "WebKit",
    "Network",
    "NSAppleScript",
    "CGEvent",
    "Process(",
)
BASELINE_RELATIVE = pathlib.Path("Schemas/core-module-boundary-baseline-v1.json")
COMPOSITION_FILES = (
    "CompanionViewModel.swift",
    "ContentView.swift",
    "CompanionSettingsView.swift",
    "ContentPack.swift",
)
FOCUSED_APP_MODULE_BUDGETS = {
    "CompanionEventSpool.swift": 450,
    "CompanionEventIngress.swift": 180,
    "CompanionEventWatcher.swift": 300,
    "ContentPackManifest.swift": 700,
    "ContentPackManifestFieldValidator.swift": 240,
    "ContentPackContributionValidationSupport.swift": 180,
    "ContentPackRightsValidator.swift": 240,
    "ContentPackAccessibilityValidator.swift": 240,
    "ContentPackFallbackValidator.swift": 80,
    "ContentPackContributionValidator.swift": 100,
    "ContentPackPackageContentsValidator.swift": 140,
    "ContentPackAssetFileValidator.swift": 140,
    "ContentPackAssetProjectionValidator.swift": 220,
    "ContentPackAssetValidator.swift": 80,
    "CompanionFailureReceipt.swift": 700,
    "SemanticVersion.swift": 120,
    "CompanionPetInteractionSurface.swift": 400,
    "CompanionWorkdayPresentation.swift": 180,
    "CompanionWorkdayApplicationProjection.swift": 140,
    "CompanionEventPresentation.swift": 100,
    "CompanionEventTriggerRouting.swift": 80,
    "ContentPackTriggerContract.swift": 100,
    "ContentPackPlaybackModels.swift": 200,
    "ContentPackRuntimeCatalog.swift": 180,
    "ContentPackRuntimeSelection.swift": 400,
    "CompanionContentSequenceRuntimeCoordinator.swift": 140,
    "ContentPackRuntimeAccessibility.swift": 240,
    "CompanionMediaAccessibilityPresentation.swift": 120,
    "ContentPackArchivePolicy.swift": 520,
    "ContentPackArchiveImporter.swift": 360,
    "CompanionContentPackImportPanel.swift": 100,
    "ContentPackRecoveryCatalog.swift": 260,
    "CompanionContentPackRecoverySection.swift": 180,
    "CompanionContentLibraryModels.swift": 100,
    "CompanionContentLibrary.swift": 170,
    "CompanionMediaPresentation.swift": 600,
    "CompanionStatusOverlays.swift": 280,
    "CompanionGestureDiscoveryCoordinator.swift": 140,
    "CompanionPresentationRuntimeCoordinator.swift": 120,
    "CompanionPetFeedbackRuntimeCoordinator.swift": 180,
    "CompanionContentLibraryRuntimeCoordinator.swift": 300,
    "CompanionPreferenceStore.swift": 420,
    "CompanionSettingsBackupProjection.swift": 240,
    "CompanionVoiceSelectionRuntimeCoordinator.swift": 140,
    "CompanionLifestyleRuntimeCoordinator.swift": 320,
    "CompanionLifestyleEventProjection.swift": 100,
    "CompanionLifestylePresentation.swift": 180,
    "CompanionContentOperationModels.swift": 100,
    "CompanionContentOperationReceiptFactory.swift": 120,
    "CompanionBackupOperationsCoordinator.swift": 220,
    "CompanionContentOperationsCoordinator.swift": 360,
    "CompanionRuntimeSupport.swift": 260,
    "CompanionRuntimeRepairCoordinator.swift": 220,
    "CompanionRuntimeReadinessPresentation.swift": 100,
    "CompanionMicrogamePresentation.swift": 220,
    "CompanionMicrogameCompletionPresentation.swift": 260,
    "CompanionTaskCompletionPresentation.swift": 180,
    "CompanionPetDragPresentation.swift": 140,
    "CompanionMicrogameRuntimeCoordinator.swift": 300,
    "CompanionExperienceRuntimeCoordinator.swift": 340,
    "CompanionWorkdayRuntimeCoordinator.swift": 300,
    "CompanionSharedDayRuntimeCoordinator.swift": 220,
    "CompanionFirstSessionRuntimeCoordinator.swift": 240,
    "CompanionFirstSessionCoach.swift": 240,
    "CompanionRelationshipRuntimeCoordinator.swift": 280,
    "CompanionRelationshipContentSelection.swift": 80,
    "ContentPackVideoDecodeFallback.swift": 80,
    "ContentPackMediaProbe.swift": 180,
    "ContentPackVideoMediaProbe.swift": 220,
    "ContentPackNonVideoMediaProbe.swift": 160,
    "ContentPackMediaCheckpointDecoder.swift": 140,
    "ContentPackMediaQualityProbe.swift": 180,
    "ContentPackStore.swift": 300,
    "ContentPackStoreRepository.swift": 120,
    "ContentPackStoreLayout.swift": 80,
    "ContentPackActiveRecordRepository.swift": 110,
    "ContentPackStoreLockCoordinator.swift": 60,
    "ContentPackInstallPreflight.swift": 140,
    "ContentPackInstallTransactions.swift": 180,
    "ContentPackRecoveryTransactions.swift": 180,
    "ContentPackPlaybackHealthTransactions.swift": 140,
    "ContentPackStoreSnapshotProjection.swift": 120,
    "ContentPackStoreMaintenanceTransactions.swift": 120,
    "ContentPackStoreModels.swift": 220,
    "ContentPackStoreDurability.swift": 140,
}
MAX_CORE_FILE_LINES = 900


class BoundaryFailure(Exception):
    def __init__(self, code: str, message: str, action: str):
        super().__init__(message)
        self.code = code
        self.message = message
        self.action = action


def fail(code: str, message: str, action: str) -> None:
    raise BoundaryFailure(code, message, action)


def regular_text(path: pathlib.Path, code: str, label: str) -> str:
    if not path.is_file() or path.is_symlink():
        fail(code, f"A required {label} is missing or unsafe.", "Restore the tracked regular file and rerun the boundary audit.")
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        fail(code, f"A required {label} is not readable UTF-8 text.", "Restore the tracked source file and rerun the boundary audit.")


def line_count(text: str) -> int:
    return len(text.splitlines())


def audit(root: pathlib.Path) -> dict[str, object]:
    core = root / CORE_RELATIVE
    app = root / APP_RELATIVE
    if not core.is_dir() or core.is_symlink() or not app.is_dir() or app.is_symlink():
        fail("CORE_BOUNDARY_REQUIRED_PATH_MISSING", "The Core or App source root is missing or unsafe.", "Restore the source layout and retry.")

    for name in REQUIRED_CORE_POLICIES:
        regular_text(core / name, "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "Core policy")
        if (app / name).exists() or (app / name).is_symlink():
            fail("CORE_BOUNDARY_LAYER_VIOLATION", "A deterministic policy is duplicated in the App composition layer.", "Keep the policy in CompanionContracts and bind it from CompanionApp.")

    swift_files = sorted(core.glob("*.swift"))
    if not swift_files:
        fail("CORE_BOUNDARY_REQUIRED_PATH_MISSING", "The Core module has no Swift sources.", "Restore the CompanionContracts sources and retry.")
    observed_imports: set[str] = set()
    policy_lines: dict[str, int] = {}
    for path in swift_files:
        text = regular_text(path, "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "Core source")
        count = line_count(text)
        if path.name in REQUIRED_CORE_POLICIES:
            policy_lines[path.name] = count
        if count > MAX_CORE_FILE_LINES:
            fail("CORE_BOUNDARY_CORE_FILE_BUDGET_EXCEEDED", "A Core policy file exceeds the reviewable size budget.", "Split the deterministic policy into focused Core files and rerun the audit.")
        imports = set(re.findall(r"^import\s+([A-Za-z0-9_]+)\s*$", text, re.MULTILINE))
        observed_imports.update(imports)
        if not imports <= ALLOWED_CORE_IMPORTS:
            fail("CORE_BOUNDARY_FORBIDDEN_DEPENDENCY", "The Core module imports a UI, media, network or unknown framework.", "Move platform integration to CompanionApp and keep Core deterministic.")
        code_without_line_comments = re.sub(r"//.*$", "", text, flags=re.MULTILINE)
        if any(token in code_without_line_comments for token in FORBIDDEN_CORE_TOKENS):
            fail("CORE_BOUNDARY_FORBIDDEN_DEPENDENCY", "The Core module contains a platform, media, network or process dependency.", "Move the side effect to CompanionApp and inject bounded facts into Core.")

    lifestyle = regular_text(core / "CompanionLifestyleScheduler.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "lifestyle policy")
    for type_name in LIFESTYLE_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", lifestyle):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The lifestyle policy lost a required cross-module public type.", "Restore the compatible public type or add a documented migration before changing it.")

    lifestyle_memory = regular_text(core / "CompanionLifestyleMemory.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "lifestyle memory contract")
    for type_name in LIFESTYLE_MEMORY_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct|final\s+class)\s+{re.escape(type_name)}\b", lifestyle_memory):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The lifestyle memory contract lost a required migration or recovery type.", "Restore the compatible versioned memory, codec and store surface before changing it.")

    workday = regular_text(core / "CompanionWorkdayState.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "shared-workday memory contract")
    for type_name in WORKDAY_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct|final\s+class)\s+{re.escape(type_name)}\b", workday):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The shared-workday contract lost a required recovery or storage type.", "Restore the compatible versioned workday state, recovery receipt and store surface before changing it.")

    workday_signal_trust = regular_text(core / "CompanionWorkdaySignalTrustPolicy.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "shared-workday signal trust policy")
    for type_name in WORKDAY_SIGNAL_TRUST_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", workday_signal_trust):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The shared-workday trust policy lost a required producer or terminal-state type.", "Restore the source/version allowlist and fail-closed terminal projection before changing event adapters.")
    for required_token in (
        '("codex-skill", "terminal-events-v1")',
        '("codex-app-server", "turn-events-v1")',
        "case (.taskCompleted, .success, .companionTerminalEmitter)",
        "case (.taskCompleted, _, _)",
    ):
        if required_token not in workday_signal_trust:
            fail("CORE_BOUNDARY_REQUIRED_PATH_MISSING", "The shared-workday trust policy lost a fail-closed producer or terminal rule.", "Restore exact producer/version classification and neutral fallback for unregistered terminal claims.")

    workday_experience = regular_text(core / "CompanionWorkdayExperiencePolicy.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "shared-workday experience policy")
    for type_name in WORKDAY_EXPERIENCE_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", workday_experience):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The shared-workday experience policy lost a required trust or presentation type.", "Restore the compatible completion-trust and attention-safe presentation surface before changing it.")

    task_completion = regular_text(core / "CompanionTaskCompletionPolicy.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "task-completion interaction policy")
    for type_name in TASK_COMPLETION_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", task_completion):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The task-completion policy lost a required celebration or reply type.", "Restore the privacy-minimal tier, relationship ceiling and bounded gesture-reply contract before changing presentation.")

    pet_drag = regular_text(core / "CompanionPetDragPolicy.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "pet drag feedback policy")
    for type_name in PET_DRAG_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", pet_drag):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The pet drag policy lost a required semantic feedback or bounded-pose type.", "Restore the deterministic fling, dock, lift, nudge and settle contract before changing direct manipulation.")

    chemistry = regular_text(core / "CompanionChemistryInteractionDirector.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "chemistry policy")
    for type_name in CHEMISTRY_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", chemistry):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The chemistry policy lost a required cross-module public type.", "Restore the compatible public type or add a documented migration before changing it.")

    user_presentation = regular_text(core / "CompanionUserPresentationPolicy.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "user presentation policy")
    for type_name in USER_PRESENTATION_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", user_presentation):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The user presentation policy lost a required cross-module public type.", "Restore the compatible public type or add a documented migration before changing it.")

    presentation_session = regular_text(core / "CompanionPresentationSession.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "presentation session contract")
    for type_name in PRESENTATION_SESSION_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", presentation_session):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The presentation session lost a required ownership or recovery type.", "Restore the compatible direct-play session contract before changing it.")

    presentation_lifecycle = regular_text(core / "CompanionPresentationLifecycle.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "presentation lifecycle contract")
    for type_name in PRESENTATION_LIFECYCLE_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", presentation_lifecycle):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The unified presentation lifecycle lost a required directive or return-policy type.", "Restore the shared click, palette, game and automatic-response lifecycle before changing it.")

    play_palette_layout = regular_text(core / "CompanionPlayPaletteLayout.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "play palette layout contract")
    for type_name in PLAY_PALETTE_LAYOUT_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", play_palette_layout):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The adaptive play-palette layout lost a required shared type.", "Restore the deterministic no-scroll layout plan before changing the play surface.")

    locale_resolution = regular_text(core / "CompanionLocaleResolutionPolicy.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "locale resolution contract")
    for type_name in LOCALE_RESOLUTION_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", locale_resolution):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The shared locale resolution policy lost its required public type.", "Restore one deterministic locale policy for media and accessibility selection before changing runtime matching.")

    first_session = regular_text(core / "CompanionFirstSession.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "first-session journey contract")
    for type_name in FIRST_SESSION_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", first_session):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The first-session journey lost a required deterministic type.", "Restore the ordered local interaction, one-preference and completion contract before changing it.")

    playback_health = regular_text(core / "CompanionPlaybackHealth.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "playback health contract")
    for type_name in PLAYBACK_HEALTH_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", playback_health):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The playback health contract lost a required bounded metric or lifecycle type.", "Restore the compatible privacy-minimal playback health surface before changing it.")

    runtime_readiness = regular_text(core / "CompanionRuntimeReadiness.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "runtime readiness contract")
    for type_name in RUNTIME_READINESS_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", runtime_readiness):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The runtime readiness contract lost a required health or bounded recovery type.", "Restore the compatible runtime health surface before changing it.")
    for function_name in RUNTIME_READINESS_REQUIRED_FUNCTIONS:
        if not re.search(rf"\bpublic\s+static\s+func\s+{re.escape(function_name)}\b", runtime_readiness):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The runtime readiness contract lost a required bounded recovery decision.", "Restore the safe-repair/manual-attention split before changing it.")

    presentation_projection = regular_text(core / "CompanionPresentationProjection.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "presentation projection policy")
    for type_name in PRESENTATION_PROJECTION_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", presentation_projection):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The presentation projection policy lost a required cross-module public type.", "Restore the compatible public type or add a documented migration before changing it.")

    projection_authoring = regular_text(core / "CompanionProjectionAuthoring.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "projection authoring contract")
    for type_name in PROJECTION_AUTHORING_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", projection_authoring):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The projection authoring contract lost a required cross-module public type.", "Restore the compatible receipt type or add a documented migration before changing it.")

    presentation_environment = regular_text(core / "CompanionPresentationEnvironment.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "presentation environment policy")
    for type_name in PRESENTATION_ENVIRONMENT_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", presentation_environment):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The presentation environment policy lost a required cross-module public type.", "Restore the compatible appearance or display-selection type before changing it.")

    settings_contract = regular_text(core / "CompanionSettings.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "settings contract")
    for type_name in PRESENTATION_SETTINGS_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", settings_contract):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The presentation settings contract lost a required persisted public type.", "Restore the compatible appearance or display-target setting before changing it.")

    microgame = regular_text(core / "CompanionMicrogameSession.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "microgame policy")
    for type_name in MICROGAME_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", microgame):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The microgame policy lost a required deterministic session type.", "Restore the content-free microgame contract or add a documented compatibility migration before changing it.")

    microgame_completion = regular_text(core / "CompanionMicrogameCompletionPolicy.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "microgame completion policy")
    for type_name in MICROGAME_COMPLETION_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", microgame_completion):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The microgame completion policy lost a required debt-free reward type.", "Restore the semantic completion plan before changing App presentation behavior.")

    microgame_window = regular_text(core / "CompanionMicrogameWindowPolicy.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "microgame window policy")
    for type_name in MICROGAME_WINDOW_PUBLIC_TYPES:
        if not re.search(rf"\bpublic\s+(?:enum|struct)\s+{re.escape(type_name)}\b", microgame_window):
            fail("CORE_BOUNDARY_PUBLIC_SURFACE_MISSING", "The microgame window policy lost a required bounded placement type.", "Restore deterministic catch and hide placement before changing AppKit window movement.")

    package = regular_text(root / "Package.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "Package manifest")
    if not re.search(
        r"name:\s*\"CompanionApp\"[\s\S]{0,300}?dependencies:\s*\[\s*\"CompanionContracts\"\s*\]",
        package,
    ):
        fail("CORE_BOUNDARY_PACKAGE_DEPENDENCY_MISSING", "CompanionApp no longer declares the Core dependency.", "Restore the one-way CompanionApp to CompanionContracts dependency and retry.")

    content_view = regular_text(app / "ContentView.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "primary presentation source")
    settings_view = regular_text(app / "CompanionSettingsView.swift", "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "settings presentation source")
    media_presentation = regular_text(
        app / "CompanionMediaPresentation.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "focused media presentation source",
    )
    status_overlays = regular_text(
        app / "CompanionStatusOverlays.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "focused status-overlay presentation source",
    )
    gesture_discovery = regular_text(
        app / "CompanionGestureDiscoveryCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "restart-safe gesture discovery coordinator",
    )
    presentation_runtime = regular_text(
        app / "CompanionPresentationRuntimeCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "focused presentation runtime coordinator",
    )
    pet_feedback_runtime = regular_text(
        app / "CompanionPetFeedbackRuntimeCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "generation-safe pet feedback runtime coordinator",
    )
    content_library_runtime = regular_text(
        app / "CompanionContentLibraryRuntimeCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "stale-safe content library runtime coordinator",
    )
    preference_store = regular_text(
        app / "CompanionPreferenceStore.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "typed local preference store",
    )
    settings_backup_projection = regular_text(
        app / "CompanionSettingsBackupProjection.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "capability-free settings backup projection",
    )
    voice_selection_runtime = regular_text(
        app / "CompanionVoiceSelectionRuntimeCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "bounded voice selection runtime coordinator",
    )
    content_sequence_runtime = regular_text(
        app / "CompanionContentSequenceRuntimeCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "focused content sequence session coordinator",
    )
    event_ingress = regular_text(
        app / "CompanionEventIngress.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "privacy-minimal event ingress",
    )
    event_watcher = regular_text(
        app / "CompanionEventWatcher.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "focused event transport watcher",
    )
    view_model = regular_text(
        app / "CompanionViewModel.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "App composition model",
    )
    for token in (
        "CompanionMicrogameWindowPolicy.catchPlacement(",
        "CompanionMicrogameWindowPolicy.hidePlacement(",
        "pointerLocation: NSEvent.mouseLocation",
        "previousEdge: hideGameLastEdge",
        "hideGameLastEdge = placement.edge",
    ):
        if token not in view_model:
            fail("CORE_BOUNDARY_POLICY_DELEGATION_MISSING", "App composition bypasses deterministic microgame window placement.", "Delegate catch and hide window geometry to CompanionMicrogameWindowPolicy and apply only the returned origin.")
    for token in (
        "let xs = [\n            visible.minX + inset",
        "let safeX = [",
        "hypot(centerX - cursor.x, centerY - cursor.y)",
        "visible.minX - size.width + 48",
    ):
        if token in view_model:
            fail("CORE_BOUNDARY_POLICY_REMERGED", "Microgame window geometry was merged back into App composition.", "Keep geometry and reachability rules in CompanionMicrogameWindowPolicy and pass only bounded display facts from AppKit.")
    for token in (
        "struct CodexTaskSignal: Sendable, Equatable",
        "enum CodexProtocolEventExtractor",
        "CompanionWorkdaySignalSourcePolicy.origin(",
        "CompanionWorkdaySignalTrustPolicy.effectiveType(",
        "privacySafeTaskReference",
    ):
        if token not in event_ingress:
            fail("CORE_BOUNDARY_REQUIRED_PATH_MISSING", "The focused event ingress lost privacy projection or producer trust delegation.", "Restore bounded envelope decoding and privacy-safe signal projection in CompanionEventIngress.swift.")
    for token in ("FileManager", "FileHandle", "URLSession", "NSWorkspace", "Process("):
        if token in event_ingress:
            fail("CORE_BOUNDARY_LAYER_VIOLATION", "The focused event ingress acquired filesystem, process or network capability.", "Keep event ingress capability-free and leave transport in CompanionEventWatcher.swift.")
    for token in (
        "actor CodexCompletionWatcher",
        "primeProtocolInbox()",
        "eventSpool.scan(root: protocolRoot",
        "CodexProtocolEventExtractor.signal(",
    ):
        if token not in event_watcher:
            fail("CORE_BOUNDARY_REQUIRED_PATH_MISSING", "The focused event watcher lost transport, restart baseline or ingress delegation.", "Restore transport-only watcher ownership and delegate envelope projection to CompanionEventIngress.swift.")
    for token in (
        "struct CodexTaskSignal",
        "enum CodexProtocolEventExtractor",
        "privacySafeTaskReference",
        "CompanionWorkdaySignalSourcePolicy.origin(",
    ):
        if token in event_watcher:
            fail("CORE_BOUNDARY_LAYER_VIOLATION", "Privacy projection was merged back into the event transport watcher.", "Keep envelope decoding and signal projection in CompanionEventIngress.swift.")
    microgame_presentation = regular_text(
        app / "CompanionMicrogamePresentation.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "microgame presentation projection",
    )
    microgame_completion_presentation = regular_text(
        app / "CompanionMicrogameCompletionPresentation.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "microgame completion presentation projection",
    )
    task_completion_presentation = regular_text(
        app / "CompanionTaskCompletionPresentation.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "task-completion presentation projection",
    )
    pet_drag_presentation = regular_text(
        app / "CompanionPetDragPresentation.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "pet drag presentation projection",
    )
    runtime_support = regular_text(
        app / "CompanionRuntimeSupport.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "runtime support projection",
    )
    runtime_repair = regular_text(
        app / "CompanionRuntimeRepairCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "runtime repair coordinator",
    )
    runtime_readiness_presentation = regular_text(
        app / "CompanionRuntimeReadinessPresentation.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "runtime readiness presentation",
    )
    lifestyle_runtime = regular_text(
        app / "CompanionLifestyleRuntimeCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "lifestyle runtime coordinator",
    )
    content_operations = regular_text(
        app / "CompanionContentOperationsCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content operations coordinator",
    )
    content_operation_models = regular_text(
        app / "CompanionContentOperationModels.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content operation models",
    )
    content_operation_receipts = regular_text(
        app / "CompanionContentOperationReceiptFactory.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content operation receipt factory",
    )
    backup_operations = regular_text(
        app / "CompanionBackupOperationsCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "backup operations coordinator",
    )
    content_library_models = regular_text(
        app / "CompanionContentLibraryModels.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content library operation models",
    )
    content_library = regular_text(
        app / "CompanionContentLibrary.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "application content library",
    )
    runtime_catalog = regular_text(
        app / "ContentPackRuntimeCatalog.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack runtime catalog",
    )
    runtime_selection = regular_text(
        app / "ContentPackRuntimeSelection.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack runtime selection policy",
    )
    playback_models = regular_text(
        app / "ContentPackPlaybackModels.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack playback models",
    )
    microgame_runtime = regular_text(
        app / "CompanionMicrogameRuntimeCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "microgame runtime coordinator",
    )
    experience_runtime = regular_text(
        app / "CompanionExperienceRuntimeCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "experience runtime coordinator",
    )
    workday_runtime = regular_text(
        app / "CompanionWorkdayRuntimeCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "workday runtime coordinator",
    )
    workday_application_projection = regular_text(
        app / "CompanionWorkdayApplicationProjection.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "workday application projection",
    )
    shared_day_runtime = regular_text(
        app / "CompanionSharedDayRuntimeCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "shared-day runtime coordinator",
    )
    first_session_runtime = regular_text(
        app / "CompanionFirstSessionRuntimeCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "first-session runtime coordinator",
    )
    content_pack_store = regular_text(
        app / "ContentPackStore.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack transaction actor",
    )
    content_pack_repository = regular_text(
        app / "ContentPackStoreRepository.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack storage facade",
    )
    content_pack_store_layout = regular_text(
        app / "ContentPackStoreLayout.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack store layout",
    )
    content_pack_active_records = regular_text(
        app / "ContentPackActiveRecordRepository.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack active-record repository",
    )
    content_pack_lock_coordinator = regular_text(
        app / "ContentPackStoreLockCoordinator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack lock coordinator",
    )
    content_pack_preflight = regular_text(
        app / "ContentPackInstallPreflight.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack install preflight",
    )
    content_pack_install_transactions = regular_text(
        app / "ContentPackInstallTransactions.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack install transactions",
    )
    content_pack_recovery_transactions = regular_text(
        app / "ContentPackRecoveryTransactions.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack recovery transactions",
    )
    content_pack_playback_health_transactions = regular_text(
        app / "ContentPackPlaybackHealthTransactions.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack playback-health transactions",
    )
    content_pack_store_snapshot_projection = regular_text(
        app / "ContentPackStoreSnapshotProjection.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack store snapshot projection",
    )
    content_pack_store_maintenance_transactions = regular_text(
        app / "ContentPackStoreMaintenanceTransactions.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack store maintenance transactions",
    )
    content_pack_video_decode_fallback = regular_text(
        app / "ContentPackVideoDecodeFallback.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack video decode fallback contract",
    )
    content_pack_media_probe = regular_text(
        app / "ContentPackMediaProbe.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack media probe",
    )
    content_pack_video_media_probe = regular_text(
        app / "ContentPackVideoMediaProbe.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack video media probe",
    )
    content_pack_non_video_media_probe = regular_text(
        app / "ContentPackNonVideoMediaProbe.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack non-video media probe",
    )
    content_pack_media_checkpoint_decoder = regular_text(
        app / "ContentPackMediaCheckpointDecoder.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack media checkpoint decoder",
    )
    content_pack_media_quality_probe = regular_text(
        app / "ContentPackMediaQualityProbe.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack media quality probe",
    )
    if re.search(r"\bstruct\s+SettingsView\b", content_view):
        fail("CORE_BOUNDARY_LAYER_VIOLATION", "The settings surface was merged back into the primary presentation file.", "Keep SettingsView in CompanionSettingsView.swift and bind it from the App scene.")
    if not re.search(r"\bstruct\s+SettingsView\s*:\s*View\b", settings_view):
        fail("CORE_BOUNDARY_REQUIRED_PATH_MISSING", "The focused settings presentation surface is missing.", "Restore SettingsView in CompanionSettingsView.swift and retry.")
    for declaration in (
        "CompanionActionView",
        "CompanionSceneVideoView",
        "CompanionMiniSceneVideoView",
        "CompanionIdleVideoView",
        "CompanionEventSpriteView",
        "AnimatedHeadPetView",
    ):
        if re.search(rf"\bstruct\s+{declaration}\s*:\s*View\b", content_view):
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Media selection or fallback presentation was merged back into the primary view.",
                "Keep the media ladder in CompanionMediaPresentation.swift and let ContentView choose only the presentation shape.",
            )
        if not re.search(rf"\bstruct\s+{declaration}\s*:\s*View\b", media_presentation):
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused media presentation surface lost a required fallback stage.",
                "Restore the pack, bundled-video and offline-sprite media ladder, then retry.",
            )

    for declaration in (
        "CompletionReplyCue",
        "CodexPresenceHalo",
        "CodexPresenceGlyph",
        "RelationshipReceiptToast",
        "SurpriseCornerStar",
    ):
        if re.search(rf"\bstruct\s+{declaration}\s*:\s*View\b", content_view):
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Status-overlay animation was merged back into the primary view.",
                "Keep focused completion, presence, relationship and surprise overlays in CompanionStatusOverlays.swift.",
            )
        if not re.search(rf"\bstruct\s+{declaration}\s*:\s*View\b", status_overlays):
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused status-overlay module lost a required presentation surface.",
                "Restore the focused overlay in CompanionStatusOverlays.swift and bind it from ContentView.",
            )
        if f"{declaration}(" not in content_view:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The primary presentation no longer binds a required status overlay.",
                "Bind the focused overlay from ContentView or provide a reviewed presentation migration.",
            )

    for token in (
        "final class CompanionGestureDiscoveryCoordinator: ObservableObject",
        "@Published private(set) var lesson",
        "private var learningState: CompanionGestureLearningState",
        "private var hintTask: Task<Void, Never>?",
        "func markLearned(",
        "func replaceLearnedIDs(",
        "func reset()",
        "func scheduleIfEligible(",
        "func cancelPendingLesson()",
    ):
        if token not in gesture_discovery:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused gesture discovery coordinator lost required restart-safe learning behavior.",
                "Restore capability-only persistence, cancellable hint scheduling and explicit reset in CompanionGestureDiscoveryCoordinator.swift.",
            )
    for token in (
        "CGPoint",
        "CGEvent",
        "NSWindow",
        "AVPlayer",
        "VoicePackPlayer",
        "URLSession",
        "Process(",
    ):
        if token in gesture_discovery:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The gesture discovery coordinator acquired pointer, window, media, speech, process or network capability.",
                "Keep the coordinator limited to opaque capability IDs, local defaults and cancellable one-time hint timing.",
            )
    for token in (
        "private let gestureDiscovery = CompanionGestureDiscoveryCoordinator()",
        "gestureDiscovery.learnedIDs",
        "gestureDiscovery.replaceLearnedIDs(",
        "gestureDiscovery.scheduleIfEligible(",
        "gestureDiscovery.cancelPendingLesson()",
        "gestureDiscovery.markLearned(",
        "gestureDiscovery.reset()",
    ):
        if token not in view_model:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The App composition model no longer delegates gesture discovery through the focused coordinator.",
                "Restore the coordinator binding without moving persistence or delayed hint ownership back into CompanionViewModel.",
            )
    for token in (
        "private var gestureLearningState",
        "private var gestureCoachTask",
        "CompanionGestureLearningState(",
        "defaults.stringArray(forKey: Keys.learnedPetGestures)",
        "defaults.removeObject(forKey: Keys.learnedPetGestures)",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Gesture learning persistence or delayed hint ownership was merged back into CompanionViewModel.",
                "Keep restart-safe learned capability IDs and cancellable hint timing in CompanionGestureDiscoveryCoordinator.swift.",
            )

    for token in (
        "struct CompanionPresentationRuntimeCoordinator",
        "private let userPolicy = CompanionUserPresentationPolicy()",
        "private var lifecycle = CompanionPresentationLifecycle()",
        "func plan(",
        "func beginDirectUserPlan(",
        "func beginAutomaticResponse(",
        "func beginContentSequence(",
        "func commitGameReward(",
        "func finish(",
        "func reset()",
    ):
        if token not in presentation_runtime:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused presentation runtime lost a required expansion or exact-restoration transition.",
                "Restore unified click, palette, content fallback, game reward and reset ownership in CompanionPresentationRuntimeCoordinator.swift.",
            )
    for token in (
        "NSWindow",
        "AVPlayer",
        "VoicePackPlayer",
        "Task<",
        "UserDefaults",
        "URLSession",
        "Process(",
    ):
        if token in presentation_runtime:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The presentation runtime coordinator acquired window, media, timing, persistence, speech, process or network capability.",
                "Keep it limited to semantic Core modes, intent, lifecycle ownership and returned directives.",
            )
    for token in (
        "var presentationRuntime = CompanionPresentationRuntimeCoordinator()",
        "presentationRuntime.beginDirectUserPlan(",
        "presentationRuntime.beginAutomaticResponse(",
        "presentationRuntime.beginContentSequence(",
        "presentationRuntime.finish(",
        "presentationRuntime.reset()",
    ):
        if token not in view_model:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The App composition model no longer delegates direct and automatic presentation ownership through the focused runtime.",
                "Restore the semantic coordinator binding while leaving window side effects in CompanionViewModel.",
            )
    for token in (
        "var presentationLifecycle = CompanionPresentationLifecycle()",
        "private let userPresentationPolicy = CompanionUserPresentationPolicy()",
        "presentationLifecycle.begin",
        "presentationLifecycle.finish(",
        "presentationLifecycle.reset()",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Presentation lifecycle or direct-play policy ownership was merged back into CompanionViewModel.",
                "Keep the mutable presentation session in CompanionPresentationRuntimeCoordinator.swift.",
            )

    for token in (
        "final class CompanionPetFeedbackRuntimeCoordinator: ObservableObject",
        "@Published private(set) var mood",
        "@Published private(set) var pose",
        "@Published private(set) var effect",
        "private var poseGeneration",
        "private var moodGeneration",
        "private var effectGeneration",
        "func schedulePoseReset(",
        "func scheduleMoodReset(",
        "func presentEffect(",
        "self.poseGeneration == generation",
        "self.moodGeneration == generation",
        "self.effectGeneration == generation",
        "isEligible()",
        "func cancelAll()",
    ):
        if token not in pet_feedback_runtime:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused pet feedback runtime lost generation-safe mood, pose or effect lifetime ownership.",
                "Restore cancellable generation-guarded feedback timing in CompanionPetFeedbackRuntimeCoordinator.swift.",
            )
    for token in (
        "AppKit",
        "SwiftUI",
        "UserDefaults",
        "URLSession",
        "NSWindow",
        "AVPlayer",
        "VoicePackPlayer",
        "FileManager",
        "Process(",
    ):
        if token in pet_feedback_runtime:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The pet feedback runtime acquired window, media, persistence, speech, filesystem, process or network capability.",
                "Keep it limited to ephemeral observable feedback state and bounded cancellable timing.",
            )
    for token in (
        "private let feedbackRuntime = CompanionPetFeedbackRuntimeCoordinator()",
        "get { feedbackRuntime.mood }",
        "get { feedbackRuntime.pose }",
        "var petEffect: PetEffect? { feedbackRuntime.effect }",
        "feedbackRuntime.objectWillChange.sink",
        "feedbackRuntime.presentEffect(",
        "feedbackRuntime.schedulePoseReset(",
        "feedbackRuntime.scheduleMoodReset(",
    ):
        if token not in view_model:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The App composition model no longer delegates ephemeral pet feedback ownership through the focused runtime.",
                "Restore the observable coordinator binding while leaving semantic interaction decisions in CompanionViewModel.",
            )
    for token in (
        "private var poseResetTask",
        "private var moodResetTask",
        "private var effectTask",
        "poseResetTask = Task",
        "moodResetTask = Task",
        "effectTask = Task",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Pet feedback timer ownership was merged back into CompanionViewModel.",
                "Keep cancellable generation-guarded mood, pose and effect timing in CompanionPetFeedbackRuntimeCoordinator.swift.",
            )

    for token in (
        "final class CompanionContentLibraryRuntimeCoordinator: ObservableObject",
        "@Published private(set) var enabledPackCount",
        "@Published private(set) var health",
        "@Published private(set) var qualitySummary",
        "@Published private(set) var summaries",
        "@Published private(set) var catalog",
        "private(set) var inventory",
        "private var recoveryGeneration",
        "private var playbackGeneration",
        "private var playbackValidations",
        "func setEnabled(",
        "func replaceInventory(",
        "func beginPlaybackValidation(",
        "func completePlaybackValidation(",
        "func failPlaybackValidation(",
        "func startRecovery(",
        "func cancelRecovery()",
        "playbackValidations[validation.key] == validation.generation",
        "recoveryGeneration == generation",
    ):
        if token not in content_library_runtime:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused content library runtime lost inventory projection or stale-callback rejection ownership.",
                "Restore generation-safe recovery/playback validation and immutable runtime projection in CompanionContentLibraryRuntimeCoordinator.swift.",
            )
    for token in (
        "AppKit",
        "SwiftUI",
        "UserDefaults",
        "URLSession",
        "NSWindow",
        "AVPlayer",
        "VoicePackPlayer",
        "FileManager",
        "Process(",
        "NSPasteboard",
    ):
        if token in content_library_runtime:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The content library runtime acquired UI, persistence, filesystem, media, speech, process or network capability.",
                "Keep it limited to immutable installed values, derived display state and cancellable local task lifetimes.",
            )
    for token in (
        "private let contentLibraryRuntime = CompanionContentLibraryRuntimeCoordinator()",
        "contentLibraryRuntime.objectWillChange.sink",
        "var installedContentPackCount: Int { contentLibraryRuntime.enabledPackCount }",
        "var contentPackHealth: String { contentLibraryRuntime.health }",
        "var contentPackCatalog: ContentPackRuntimeCatalog { contentLibraryRuntime.catalog }",
        "contentLibraryRuntime.setEnabled(localContentPacksEnabled)",
        "contentLibraryRuntime.startRecovery(",
        ".beginPlaybackValidation(reference)",
        "contentLibraryRuntime.completePlaybackValidation(",
        "contentLibraryRuntime.failPlaybackValidation(",
    ):
        if token not in view_model:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The App composition model no longer delegates content-library runtime ownership through the focused coordinator.",
                "Restore the observable coordinator binding while leaving disk transactions in CompanionContentOperationsCoordinator.",
            )
    for token in (
        "private var contentPackRecoveryTask",
        "private var contentPackInventory",
        "private var reportedPackPlaybackKeys",
        "private func applyContentPackInventory",
        "private func setContentPackAvailableHealth",
        "@Published private(set) var contentPackCatalog",
        "@Published private(set) var contentPackHealth",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Content-library inventory, recovery or playback-validation state was merged back into CompanionViewModel.",
                "Keep runtime projection and stale-callback ownership in CompanionContentLibraryRuntimeCoordinator.swift.",
            )

    for token in (
        "struct CompanionPreferenceSnapshot: Equatable",
        "struct CompanionPreferenceLoadReceipt: Equatable",
        "final class CompanionPreferenceStore",
        "func load() -> CompanionPreferenceLoadReceipt",
        "upgradedPlaybackSelectionContract",
        "repairedFieldCount",
        "removedDeprecatedKeyCount",
        "storedContractVersion < Self.playbackSelectionContractVersion",
        "range: 0...Int.max",
        "removeDeprecatedConversationKeys()",
        "guard target.isValid else",
        "range: 0...5",
        "func savePlaybackMode(",
        "func saveLocalContentPacksEnabled(",
        "func saveCatchGameBestScore(",
        "func saveHideGameBestScore(",
    ):
        if token not in preference_store:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused preference store lost typed defaults, migration, repair or privacy-cleanup ownership.",
                "Restore the local preference schema and restart-safe repair receipt in CompanionPreferenceStore.swift.",
            )
    for token in (
        "AppKit",
        "SwiftUI",
        "URLSession",
        "NSWindow",
        "AVPlayer",
        "VoicePackPlayer",
        "FileManager",
        "Process(",
        "NSPasteboard",
        "CodexTaskSignal",
        "@Published",
        "ObservableObject",
    ):
        if token in preference_store:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The preference store acquired UI, observation, filesystem, media, task-content, process or network capability.",
                "Keep it limited to typed UserDefaults projection, bounded repair and retired-key cleanup.",
            )
    for token in (
        "private let preferenceStore = CompanionPreferenceStore()",
        "let savedPreferences = preferenceStore.load().snapshot",
        "preferenceStore.savePlaybackMode(playbackMode)",
        "preferenceStore.saveDisplayTarget(displayTarget)",
        "preferenceStore.saveLocalContentPacksEnabled(localContentPacksEnabled)",
        "preferenceStore.saveCatchGameBestScore(catchGameBestScore)",
        "preferenceStore.saveHideGameBestScore(hideGameBestScore)",
    ):
        if token not in view_model:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The App composition model no longer delegates preference migration and persistence through the focused store.",
                "Restore the typed preference-store binding while leaving UI side effects in CompanionViewModel.",
            )
    for token in (
        "defaults.set(",
        "defaults.object(forKey:",
        "defaults.bool(forKey:",
        "defaults.string(forKey:",
        "defaults.integer(forKey:",
        "defaults.removeObject(forKey:",
        "CompanionPresentationPreferences.load",
        "CompanionPresentationPreferences.save",
        '"chengyin.ui.messages"',
        '"chengyin.codex.thread-id"',
        "private typealias Keys = CompanionDefaultsKeys",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Preference key, migration, repair or retired privacy cleanup ownership returned to CompanionViewModel.",
                "Keep all local preference persistence in CompanionPreferenceStore.swift.",
            )

    for token in (
        "enum CompanionSettingsRestoreRepair: String, Equatable, CaseIterable",
        "struct CompanionSettingsRestorePlan: Equatable",
        "enum CompanionSettingsBackupProjection",
        'static let supportedPersonaID = "starter.c01"',
        "static func export(",
        "static func restore(",
        "currentLocale: String",
        "settings.displayTarget.isValid",
        "repairs.append(.unsupportedPersona)",
        "repairs.append(.localeFollowsCurrentApp)",
        "repairs.append(.soundToggleUnsupported)",
        "repairs.append(.sharingPromptDiscarded)",
        "repairs.append(.invalidDisplayTarget)",
        "repairs.append(.reducedDynamicsForcedAudioOnly)",
        "repairs.append(.flirtyReminderDisallowedByTone)",
        "repairs.append(.petNameDisallowedByTone)",
        "soundEnabled: true",
        "sharingPromptEnabled: false",
    ):
        if token not in settings_backup_projection:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused settings-backup projection lost export, safe restore or explicit repair-receipt ownership.",
                "Restore capability-free settings backup projection in CompanionSettingsBackupProjection.swift.",
            )
    for token in (
        "AVFoundation",
        "AVAudioPlayer",
        "AppKit",
        "SwiftUI",
        "UserDefaults",
        "FileManager",
        "Data(contentsOf:",
        "Bundle.",
        "URLSession",
        "NSWindow",
        "NSPasteboard",
        "Process(",
        "Task {",
        "@Published",
        "ObservableObject",
    ):
        if token in settings_backup_projection:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The settings-backup projection acquired UI, persistence, media, filesystem, process or network capability.",
                "Keep it limited to pure settings export, restore planning and ordered repair receipts.",
            )
    for token in (
        "CompanionSettingsBackupProjection.export(",
        "preferences: preferenceStore.load().snapshot",
        "CompanionSettingsBackupProjection.restore(",
        "contentOperations.presentBackupRestoreCompletion(",
        "return plan.repairs",
    ):
        if token not in view_model:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The App composition model no longer delegates portable settings projection and repair receipts through the focused boundary.",
                "Restore CompanionSettingsBackupProjection delegation while leaving runtime side effects in CompanionViewModel.",
            )
    for token in (
        "CompanionSettingsV1(",
        "settings.displayTarget.isValid",
        "settings.relationshipTone.allowsFlirtyReminders",
        "settings.relationshipTone.allowsRomanticGestures",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Portable settings export or compatibility repair policy returned to CompanionViewModel.",
                "Keep backup mapping and compatibility decisions in CompanionSettingsBackupProjection.swift.",
            )

    for token in (
        "enum CompanionInteractionVoiceSelection: Equatable",
        "final class CompanionVoiceSelectionRuntimeCoordinator",
        "private var recentGeneralIDs: [String] = []",
        "private var recentInteractionIDs: [String] = []",
        "private var lastInteractionCueAt = Date.distantPast",
        "var audioFileNames: [String]",
        "func selectEvent(",
        "preferredID: String? = nil",
        "func selectAction(",
        "func selectInteraction(",
        "recentGeneralIDs.suffix(10)",
        "recentInteractionIDs.suffix(8)",
        "now.timeIntervalSince(lastInteractionCueAt) < 0.32",
    ):
        if token not in voice_selection_runtime:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused voice-selection runtime lost bounded history, preferred-ID filtering or cooldown ownership.",
                "Restore session-local voice selection in CompanionVoiceSelectionRuntimeCoordinator.swift.",
            )
    for token in (
        "AVFoundation",
        "AVAudioPlayer",
        "VoicePackPlayer",
        "AppKit",
        "SwiftUI",
        "UserDefaults",
        "FileManager",
        "Data(contentsOf:",
        "Bundle.",
        "URLSession",
        "NSWindow",
        "NSPasteboard",
        "Process(",
        "Task {",
        "@Published",
        "ObservableObject",
    ):
        if token in voice_selection_runtime:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The voice-selection runtime acquired playback, UI, persistence, bundle-loading, process or network capability.",
                "Keep it limited to an injected voice library, bounded history and semantic selection receipts.",
            )
    for token in (
        "private let voiceSelection = CompanionVoiceSelectionRuntimeCoordinator(",
        "voiceFileNames: voiceSelection.audioFileNames",
        "voiceSelection.selectAction(",
        "voiceSelection.selectEvent(",
        "voiceSelection.selectInteraction(",
    ):
        if token not in view_model:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The App composition model no longer delegates voice selection through the focused runtime.",
                "Restore voiceSelection binding while leaving AVFoundation playback and UI projection in CompanionViewModel.",
            )
    for token in (
        "private let voiceLines = VoiceLineLibrary.load()",
        "private var recentVoiceLineIDs",
        "private var recentInteractionLineIDs",
        "private var lastInteractionCueAt",
        "voiceLines.candidates(",
        "recentVoiceLineIDs.append(",
        "recentInteractionLineIDs.append(",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Voice candidate history, preferred selection or cooldown ownership returned to CompanionViewModel.",
                "Keep all session-local voice-selection state in CompanionVoiceSelectionRuntimeCoordinator.swift.",
            )

    for token in (
        "final class CompanionContentSequenceRuntimeCoordinator<Fallback>",
        "@Published private(set) var activeSequence",
        "func selectVideo(",
        "func selectAndBegin(",
        "func finish(",
        "func cancelActive()",
        "func resetSelectionCache()",
    ):
        if token not in content_sequence_runtime:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused content sequence runtime lost session, cache or stale-callback ownership.",
                "Restore single active-sequence, fallback and selection-cache ownership in CompanionContentSequenceRuntimeCoordinator.swift.",
            )
    for token in (
        "FileManager",
        "FileHandle",
        "AVPlayer",
        "VoicePackPlayer",
        "NSWindow",
        "UserDefaults",
        "URLSession",
        "Process(",
    ):
        if token in content_sequence_runtime:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The content sequence runtime acquired filesystem, media, speech, window, persistence, process or network capability.",
                "Keep the coordinator limited to immutable catalog selection and session-local sequence state.",
            )
    for token in (
        "CompanionContentSequenceRuntimeCoordinator<ContentSequenceFallback>()",
        "contentSequenceRuntime.selectVideo(",
        "contentSequenceRuntime.selectAndBegin(",
        "contentSequenceRuntime.finish(",
        "contentSequenceRuntime.cancelActive()",
        "contentSequenceRuntime.resetSelectionCache()",
    ):
        if token not in view_model:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The App composition model no longer delegates content sequence session ownership through the focused runtime.",
                "Restore coordinator delegation while leaving media, speech and window effects in CompanionViewModel.",
            )
    for token in (
        "private var selectedContentAssetKey",
        "private var selectedContentAsset:",
        "private var activeContentSequenceFallback",
        "activeContentSequence = nil",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Content selection cache or active-sequence session state was merged back into CompanionViewModel.",
                "Keep selected-asset cache, active sequence and fallback ownership in CompanionContentSequenceRuntimeCoordinator.swift.",
            )

    if "private let repository: ContentPackStoreRepository" not in content_pack_store:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The content-pack transaction actor lost its focused storage repository.",
            "Restore ContentPackStoreRepository ownership and keep filesystem layout outside the transaction actor.",
        )
    if "private let installPreflight: ContentPackInstallPreflight" not in content_pack_store:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The content-pack transaction actor lost its focused read-only install preflight.",
            "Restore ContentPackInstallPreflight ownership and keep trust/compatibility inspection outside the transaction actor.",
        )
    for token in (
        "private let installTransactions: ContentPackInstallTransactions",
        "installTransactions.stage(",
        "installTransactions.commit(",
        "installTransactions.discard(",
    ):
        if token not in content_pack_store:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The content-pack actor lost lock-scoped install delegation.",
                "Restore staging, commit and cleanup delegation through ContentPackInstallTransactions.",
            )
    if "private let recoveryTransactions: ContentPackRecoveryTransactions" not in content_pack_store:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The content-pack transaction actor lost its lock-scoped recovery component.",
            "Restore ContentPackRecoveryTransactions ownership and keep the actor as the only recovery entry point.",
        )
    if (
        "private let playbackHealthTransactions: ContentPackPlaybackHealthTransactions"
        not in content_pack_store
    ):
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The content-pack transaction actor lost its lock-scoped playback-health component.",
            "Restore ContentPackPlaybackHealthTransactions ownership and keep the actor as the only playback-health entry point.",
        )
    for token in (
        "private let snapshotProjection: ContentPackStoreSnapshotProjection",
        "func snapshot() throws -> ContentPackStoreSnapshot",
        "snapshotProjection.inventory(lockedBy: scope)",
        "snapshotProjection.snapshot(lockedBy: scope)",
    ):
        if token not in content_pack_store:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The content-pack transaction actor lost its lock-scoped snapshot projection.",
                "Restore one-lock active/recovery snapshot publication through ContentPackStoreSnapshotProjection.",
            )
    for token in (
        "private let maintenanceTransactions: ContentPackStoreMaintenanceTransactions",
        "maintenanceTransactions.rollback(",
        "maintenanceTransactions.recoverInterruptedInstalls(",
    ):
        if token not in content_pack_store:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The content-pack transaction actor lost its lock-scoped maintenance delegation.",
                "Restore explicit rollback and abandoned-staging cleanup through ContentPackStoreMaintenanceTransactions.",
            )
    for token in (
        "guard current.health == .pendingHealth",
        "ContentPackStoreError.activeVersionChanged(",
        "let replacement: ActiveContentPackRecord",
    ):
        if token in content_pack_store:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Playback-health transition policy was merged back into the transaction actor.",
                "Keep mark/report entry points in ContentPackStore and lock-scoped transition policy in ContentPackPlaybackHealthTransactions.",
            )
    for token in (
        "private let root: URL",
        "private var packsRoot: URL",
        "private var stagingRoot: URL",
        "private var removedRoot: URL",
        "private func readActiveRecord(",
        "private func writeActiveRecord(",
        "private func authorize(",
        "ContentPackValidator.sha256(",
        "ContentPackAtomicFileWriter.write(",
        "ContentPackStoreFileLock.acquire(",
        "repository.acquireStoreLock(",
        "private func restoreRemovalLocked(",
        "let directories = try repository.fileManager.contentsOfDirectory(",
        "let target = repository.versionDirectory(",
        "let candidates = try repository.fileManager.contentsOfDirectory(",
        "candidate.lastPathComponent.hasSuffix(\".staging\")",
        "lstat(",
        "repository.recoveryCatalog",
        "repository.fileManager.copyItem(",
        "repository.fileManager.moveItem(",
        "repository.fileManager.removeItem(",
        "repository.writeActiveRecord(",
        "var committedVersionDirectory",
        "var activationCompleted",
    ):
        if token in content_pack_store:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Content-pack storage layout or active-record durability was merged back into the transaction actor.",
                "Keep install decisions in ContentPackStore and path/record projection in ContentPackStoreRepository.",
            )
    for token in (
        "struct ContentPackStoreRepository",
        "private let layout: ContentPackStoreLayout",
        "private let activeRecords: ContentPackActiveRecordRepository",
        "private let lockCoordinator: ContentPackStoreLockCoordinator",
        "var packsRoot: URL",
        "var stagingRoot: URL",
        "var removedRoot: URL",
        "func readActiveRecord(",
        "func writeActiveRecord(",
        "func installedPack(",
        "func withStoreLock<",
        "try layout.prepareStore()",
        "try activeRecords.read(packID: packID)",
        "try activeRecords.write(record)",
        "try activeRecords.installedPack(for: record)",
        "try lockCoordinator.withLock(operation)",
    ):
        if token not in content_pack_repository:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The content-pack storage facade lost a required delegation.",
                "Restore explicit layout, active-record and lock-coordinator delegation, then retry.",
            )
    for token in (
        "JSONDecoder",
        "JSONEncoder",
        "ContentPackAtomicFileWriter.write(",
        "ContentPackStoreFileLock.acquire(",
        "ContentPackStoreLockScope()",
        "createDirectory(",
        "func install(",
        "func rollback(",
        "func remove(",
        "func markPlaybackSucceeded(",
        "func reportPlaybackFailure(",
        "func authorize(",
        "mediaProbe",
        "signatureVerifier",
        "entitlementChecker",
    ):
        if token in content_pack_repository:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The storage facade remerged layout, record, lock or transaction policy.",
                "Keep the facade limited to delegation and return each capability to its focused component.",
            )

    for token in (
        "struct ContentPackStoreLayout",
        "root.standardizedFileURL",
        "var packsRoot: URL",
        "var stagingRoot: URL",
        "var removedRoot: URL",
        "func packDirectory(",
        "func versionDirectory(",
        "func prepareStore()",
        "func createPrivateDirectory(",
        "fileManager.createDirectory(",
        ".posixPermissions: 0o700",
    ):
        if token not in content_pack_store_layout:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The content-pack store layout lost a required private-directory responsibility.",
                "Restore normalized store paths plus 0700 directory preparation without record or lock policy.",
            )
    for token in (
        "JSONDecoder",
        "JSONEncoder",
        "ContentPackValidator",
        "ContentPackStoreFileLock",
        "ContentPackStoreLockScope",
        "ActiveContentPackRecord",
        "InstalledContentPack",
    ):
        if token in content_pack_store_layout:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The content-pack store layout gained record, validation or lock policy.",
                "Keep this component limited to private directory topology and permissions.",
            )

    for token in (
        "struct ContentPackActiveRecordRepository",
        "func validateIdentifier(",
        "func read(packID:",
        "func write(_ record:",
        "func installedPack(",
        "ActiveContentPackRecord.currentSchemaVersion",
        "record.packID == packID",
        "SemanticVersion(record.version)",
        "decoder.dateDecodingStrategy = .iso8601",
        "encoder.dateEncodingStrategy = .iso8601",
        "ContentPackAtomicFileWriter.write(",
        "validator.loadAndValidate(",
        "manifest.id == record.packID",
        "manifest.version == record.version",
    ):
        if token not in content_pack_active_records:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The active-record repository lost validation or durable projection.",
                "Restore exact schema, identifier, version, ISO-8601 and manifest consistency checks.",
            )
    for token in (
        "ContentPackStoreFileLock",
        "ContentPackStoreLockScope",
        "func prepareStore(",
        "var packsRoot:",
        "var stagingRoot:",
        "var removedRoot:",
        "func install(",
        "func rollback(",
    ):
        if token in content_pack_active_records:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The active-record repository gained layout, lock or transaction policy.",
                "Keep it limited to validated active.json persistence and installed-pack projection.",
            )

    for token in (
        "struct ContentPackStoreLockScope",
        "fileprivate init() {}",
        "struct ContentPackStoreLockCoordinator",
        "ContentPackStoreFileLock.acquire(",
        'appendingPathComponent(".pack-store.lock")',
        "defer { storeLock.release() }",
        "ContentPackStoreLockScope()",
    ):
        if token not in content_pack_lock_coordinator:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The store lock coordinator lost lexical lock ownership or its unforgeable scope.",
                "Restore synchronous acquire/release and keep the scope constructor fileprivate in this file.",
            )
    for token in (
        "JSONDecoder",
        "JSONEncoder",
        "ContentPackValidator",
        "FileManager",
        "createDirectory(",
        "ActiveContentPackRecord",
        "InstalledContentPack",
        "async ",
        "await ",
    ):
        if token in content_pack_lock_coordinator:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The store lock coordinator gained layout, record, validation or async policy.",
                "Keep it limited to one synchronous cross-process lock and lexical scope publication.",
            )

    scope_constructors = []
    for source_path in sorted(app.glob("*.swift")):
        if "ContentPackStoreLockScope()" in regular_text(
            source_path,
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "App source",
        ):
            scope_constructors.append(source_path.name)
    if scope_constructors != ["ContentPackStoreLockCoordinator.swift"]:
        fail(
            "CORE_BOUNDARY_LAYER_VIOLATION",
            "The store-lock scope can be constructed outside its coordinator.",
            "Keep ContentPackStoreLockScope() private to ContentPackStoreLockCoordinator.swift.",
        )

    for token in (
        "struct ContentPackInstallPreflight",
        "func loadCandidateManifest(",
        "func validateCandidate(",
        "func validateVersionTransition(",
        "func activationRecord(",
        "private func authorize(",
        "signatureVerifier",
        "entitlementChecker",
        "ContentPackValidator.sha256(",
    ):
        if token not in content_pack_preflight:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused content-pack install preflight lost a trust or compatibility responsibility.",
                "Restore read-only manifest, authorization, transition and exact-revision checks, then retry.",
            )
    for token in (
        "copyItem(",
        "moveItem(",
        "removeItem(",
        "writeActiveRecord(",
        "createPrivateDirectory(",
        "acquireStoreLock(",
        "withStoreLock",
        "ContentPackAtomicFileWriter",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        if token in content_pack_preflight:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The read-only install preflight gained filesystem mutation, locking or unrelated capability.",
                "Keep every lock and mutation in the transaction actor/repository boundary; preflight may inspect only.",
            )

    for token in (
        "struct ContentPackInstallTransactions",
        "let repository: ContentPackStoreRepository",
        "let preflight: ContentPackInstallPreflight",
        "func stage(",
        "func commit(",
        "func discard(",
        "lockedBy scope: ContentPackStoreLockScope",
        "repository.fileManager.copyItem(",
        "preflight.validateCandidate(",
        "preflight.validateVersionTransition(",
        "repository.fileManager.moveItem(",
        "repository.writeActiveRecord(",
        "private func discardOwnedStaging(",
        "normalized.lastPathComponent.hasSuffix(\".staging\")",
    ):
        if token not in content_pack_install_transactions:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The lock-scoped install component lost a required transaction responsibility.",
                "Restore capability-gated staging, final revalidation, commit, activation and owned cleanup.",
            )
    for token in (
        "withStoreLock",
        "acquireStoreLock(",
        "ContentPackStoreFileLock",
        "async ",
        "await ",
        "mediaProbe",
        "signatureVerifier",
        "entitlementChecker",
        "repository.removedRoot",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        if token in content_pack_install_transactions:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The install transaction component gained lock ownership, async work, broad recovery reach or unrelated capability.",
                "Keep locking and media decode outside; limit mutations to owned staging and a pre-activation committed version.",
            )
    if content_pack_install_transactions.count(
        "lockedBy scope: ContentPackStoreLockScope"
    ) != 3:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "A content-pack install mutation no longer requires the unforgeable store-lock scope.",
            "Require ContentPackStoreLockScope on stage, commit and discard.",
        )

    for token in (
        "struct ContentPackRecoveryTransactions",
        "let repository: ContentPackStoreRepository",
        "func restoreAfterFailedBatch(",
        "func remove(",
        "func inventory(",
        "func restoreItem(",
        "func purgeItem(",
        "func restoreRemoval(",
        "lockedBy scope: ContentPackStoreLockScope",
        "repository.recoveryCatalog",
        "repository.writeActiveRecord(",
        "lstat(",
    ):
        if token not in content_pack_recovery_transactions:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The lock-scoped recovery component lost a required mutation or capability boundary.",
                "Restore capability-gated removal, inventory, restore, purge and batch rollback, then retry.",
            )
    for token in (
        "withStoreLock",
        "acquireStoreLock(",
        "ContentPackStoreFileLock",
        "async ",
        "await ",
        "mediaProbe",
        "signatureVerifier",
        "entitlementChecker",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        if token in content_pack_recovery_transactions:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The recovery component gained lock ownership, async work or unrelated capability.",
                "Keep locking in ContentPackStoreRepository, entry-point serialization in ContentPackStore and recovery mutations synchronous.",
            )
    if content_pack_recovery_transactions.count(
        "lockedBy scope: ContentPackStoreLockScope"
    ) != 6:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "A recovery mutation no longer requires the unforgeable store-lock scope.",
            "Require ContentPackStoreLockScope on all six recovery transaction entry points.",
        )
    for token in (
        "struct ContentPackPlaybackHealthTransactions",
        "let repository: ContentPackStoreRepository",
        "func markSucceeded(",
        "func reportFailure(",
        "private func activeRecord(",
        "lockedBy scope: ContentPackStoreLockScope",
        "guard current.health == .pendingHealth",
        "health: .healthy",
        "health: .disabled",
        "repository.writeActiveRecord(",
        "repository.validator.loadAndValidate(",
    ):
        if token not in content_pack_playback_health_transactions:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The lock-scoped playback-health component lost a required transition or capability boundary.",
                "Restore exact-version validation, pending-health rollback/disable transitions and durable active-record publication.",
            )
    for token in (
        "withStoreLock",
        "acquireStoreLock(",
        "ContentPackStoreFileLock",
        "async ",
        "await ",
        "mediaProbe",
        "signatureVerifier",
        "entitlementChecker",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        if token in content_pack_playback_health_transactions:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The playback-health component gained lock ownership, async work or unrelated capability.",
                "Keep locking in ContentPackStoreRepository, entry-point serialization in ContentPackStore and health transitions synchronous.",
            )
    if content_pack_playback_health_transactions.count(
        "lockedBy scope: ContentPackStoreLockScope"
    ) != 2:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "A playback-health mutation no longer requires the unforgeable store-lock scope.",
            "Require ContentPackStoreLockScope on both playback-health transaction entry points.",
        )

    for token in (
        "struct ContentPackStoreSnapshotProjection",
        "let repository: ContentPackStoreRepository",
        "let recoveryTransactions: ContentPackRecoveryTransactions",
        "func inventory(",
        "func snapshot(",
        "lockedBy scope: ContentPackStoreLockScope",
        "let directories = try repository.fileManager.contentsOfDirectory(",
        "recoveryTransactions.inventory(lockedBy: scope)",
        ".sorted { $0.record.packID < $1.record.packID }",
    ):
        if token not in content_pack_store_snapshot_projection:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The lock-scoped content-store snapshot projection lost a required read responsibility.",
                "Restore active inventory plus recovery projection under the caller-provided store-lock scope.",
            )
    for token in (
        "withStoreLock",
        "acquireStoreLock(",
        "ContentPackStoreFileLock",
        "writeActiveRecord(",
        "copyItem(",
        "moveItem(",
        "removeItem(",
        "createPrivateDirectory(",
        "async ",
        "await ",
        "mediaProbe",
        "signatureVerifier",
        "entitlementChecker",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        if token in content_pack_store_snapshot_projection:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The content-store snapshot projection gained lock ownership, mutation, async work or unrelated capability.",
                "Keep it synchronous and read-only; ContentPackStoreRepository owns locking and ContentPackStore owns entry-point serialization.",
            )
    if content_pack_store_snapshot_projection.count(
        "lockedBy scope: ContentPackStoreLockScope"
    ) != 2:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "A content-store snapshot read no longer requires the unforgeable store-lock scope.",
            "Require ContentPackStoreLockScope on both inventory and combined snapshot projection.",
        )

    for token in (
        "struct ContentPackStoreMaintenanceTransactions",
        "let repository: ContentPackStoreRepository",
        "func rollback(",
        "func recoverInterruptedInstalls(",
        "lockedBy scope: ContentPackStoreLockScope",
        "let target = repository.versionDirectory(",
        "repository.validator.loadAndValidate(",
        "repository.writeActiveRecord(",
        "at: repository.stagingRoot",
        "candidate.lastPathComponent.hasSuffix(\".staging\")",
    ):
        if token not in content_pack_store_maintenance_transactions:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The lock-scoped content-pack maintenance component lost a required responsibility.",
                "Restore validated rollback plus bounded abandoned-staging cleanup under the caller-provided lock scope.",
            )
    for token in (
        "withStoreLock",
        "acquireStoreLock(",
        "ContentPackStoreFileLock",
        "repository.packsRoot",
        "repository.removedRoot",
        "async ",
        "await ",
        "mediaProbe",
        "signatureVerifier",
        "entitlementChecker",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        if token in content_pack_store_maintenance_transactions:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The content-pack maintenance component gained lock ownership, broad storage reach, async work or unrelated capability.",
                "Keep it synchronous and capability-scoped to validated prior versions plus direct children of the staging root.",
            )
    if content_pack_store_maintenance_transactions.count(
        "lockedBy scope: ContentPackStoreLockScope"
    ) != 2:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "A content-pack maintenance mutation no longer requires the unforgeable store-lock scope.",
            "Require ContentPackStoreLockScope on both rollback and interrupted-install cleanup.",
        )

    for token in (
        "typealias CompanionContentInstallSnapshot",
        "typealias CompanionContentPackSnapshot",
        "typealias CompanionContentRemovalSnapshot",
        "typealias CompanionContentRestoreSnapshot",
        "typealias CompanionContentRecoverySnapshot",
        "typealias CompanionContentBackupRestoreSnapshot",
        "typealias CompanionContentMaintenanceSnapshot",
    ):
        if token not in content_library_models:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The application content-library operation shapes are incomplete.",
                "Restore the named internal result shapes so the actor does not grow inline tuple contracts.",
            )
    for token in (
        "actor ",
        "class ",
        "func ",
        "async ",
        "await ",
        "FileManager",
        "UserDefaults",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        if token in content_library_models:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The content-library operation models gained behavior, persistence, UI, network or process capability.",
                "Keep the file data-only and leave all side effects in CompanionContentLibrary.",
            )
    for token in (
        "actor CompanionContentLibrary",
        "store.snapshot()",
        "CompanionContentInstallSnapshot",
        "CompanionContentRemovalSnapshot",
        "CompanionContentRestoreSnapshot",
        "CompanionContentRecoverySnapshot",
        "CompanionContentMaintenanceSnapshot",
    ):
        if token not in content_library:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The application content library lost coherent snapshot or named-result delegation.",
                "Restore single-call store snapshots after recovery-affecting operations and keep operation shapes in CompanionContentLibraryModels.swift.",
            )
    if "store.recoveryInventory()" in content_library:
        fail(
            "CORE_BOUNDARY_LAYER_VIOLATION",
            "The application content library rebuilt active/recovery UI state from separate actor calls.",
            "Use one ContentPackStore.snapshot() so active and recovery inventory share a repository-lock boundary.",
        )
    if "typealias " in content_library:
        fail(
            "CORE_BOUNDARY_LAYER_VIOLATION",
            "Content-library result contracts were merged back into the actor.",
            "Keep named operation shapes in CompanionContentLibraryModels.swift.",
        )
    for source_path in sorted(app.glob("*.swift")):
        if source_path.name == "ContentPackStore.swift":
            continue
        source_text = regular_text(
            source_path,
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "App source",
        )
        if "ContentPackRecoveryTransactions(" in source_text:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Recovery transaction capability is constructed outside ContentPackStore.",
                "Keep ContentPackStore as the sole actor-isolated owner of recovery transactions.",
            )
        if "ContentPackInstallTransactions(" in source_text:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Install transaction capability is constructed outside ContentPackStore.",
                "Keep ContentPackStore as the sole actor-isolated owner of staging and activation transactions.",
            )
        if "ContentPackPlaybackHealthTransactions(" in source_text:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Playback-health transaction capability is constructed outside ContentPackStore.",
                "Keep ContentPackStore as the sole actor-isolated owner of playback-health transactions.",
            )
        if "ContentPackStoreSnapshotProjection(" in source_text:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Content-store snapshot projection is constructed outside ContentPackStore.",
                "Keep ContentPackStore as the sole actor-isolated owner of the lock-scoped snapshot projection.",
            )
        if "ContentPackStoreMaintenanceTransactions(" in source_text:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Content-pack maintenance capability is constructed outside ContentPackStore.",
                "Keep ContentPackStore as the sole actor-isolated owner of rollback and staging maintenance.",
            )

    for token in (
        "protocol ContentPackVideoDecodeFallback",
        "var backendID: String { get }",
        "func decodeVideo(",
    ):
        if token not in content_pack_video_decode_fallback:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The narrow external video-decode contract lost a required declaration.",
                "Restore the decode-only protocol without adding a runtime implementation.",
            )
    for token in (
        "import AppKit",
        "import SwiftUI",
        "import Network",
        "import AVFoundation",
        "URLSession",
        "Process(",
        "FileManager.default",
    ):
        if token in content_pack_video_decode_fallback:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The video-decode fallback contract gained a concrete UI, network, process, media or storage capability.",
                "Keep only the decode protocol in App and its restricted implementation in creator tooling.",
            )
    if "protocol ContentPackVideoDecodeFallback" in content_pack_media_probe \
            or "protocol ContentPackVideoDecodeFallback" in content_pack_video_media_probe:
        fail(
            "CORE_BOUNDARY_LAYER_VIOLATION",
            "The external video-decode contract was merged back into the format probe.",
            "Keep the protocol in ContentPackVideoDecodeFallback.swift and the video checks in ContentPackVideoMediaProbe.swift.",
        )
    if "ContentPackVideoDecodeFallback" not in content_pack_video_media_probe:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The video probe lost its optional decode-only fallback binding.",
            "Restore the optional protocol dependency in the focused video probe while leaving runtime construction unset.",
        )

    for token in (
        "ContentPackNonVideoMediaProbing",
        "ContentPackVideoMediaProbing",
        "videoProbe.probeVideo(",
        "nonVideoProbe.probeAudio(",
        "nonVideoProbe.probeImage(",
        "nonVideoProbe.probeJSON(",
    ):
        if token not in content_pack_media_probe:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The media router lost focused video or non-video delegation.",
                "Restore kind-only routing to ContentPackVideoMediaProbe.swift and ContentPackNonVideoMediaProbe.swift.",
            )
    for token in (
        "AVURLAsset(",
        "AVAssetImageGenerator(",
        "loadTracks(withMediaType:",
        "kCMVideoCodecType_H264",
        "ContentPackMediaQualityProbe().probe(",
        "CGImageSourceCreateWithURL(",
        "JSONSerialization.jsonObject(",
        "private func probeAudio(",
        "private func probeImage(",
        "private func probeJSON(",
    ):
        if token in content_pack_media_probe:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Concrete video or non-video decoding was merged back into the media router.",
                "Keep the router limited to iteration, kind dispatch and stable error projection.",
            )

    for token in (
        "protocol ContentPackVideoMediaProbing",
        "struct AVFoundationContentPackVideoMediaProbe",
        "func probeVideo(",
        "AVURLAsset(",
        "loadTracks(withMediaType: .video)",
        "kCMVideoCodecType_H264",
        "kCMVideoCodecType_HEVC",
        "AVAssetImageGenerator(",
        "ContentPackMediaQualityProbe().probe(",
        "ContentPackVideoDecodeFallback",
    ):
        if token not in content_pack_video_media_probe:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused video probe lost a required validation or fallback boundary.",
                "Restore container, track, declaration, first-frame, quality and narrow fallback validation in ContentPackVideoMediaProbe.swift.",
            )
    for token in (
        "import AppKit",
        "import SwiftUI",
        "import Network",
        "URLSession",
        "Process(",
        "FileManager.default",
        "CGImageSourceCreateWithURL(",
        "JSONSerialization.jsonObject(",
        "ContentPackStore",
        "ContentPackValidator.sha256(",
    ):
        if token in content_pack_video_media_probe:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The focused video probe gained UI, network, process, broad storage, non-video decoding or hashing capability.",
                "Keep it read-only, AVFoundation-focused and limited to the caller-provided asset URL.",
            )
    for token in (
        "protocol ContentPackNonVideoMediaProbing",
        "struct SystemContentPackNonVideoMediaProbe",
        "func probeAudio(",
        "func probeImage(",
        "func probeJSON(",
        "CGImageSourceCreateWithURL(",
        "JSONSerialization.jsonObject(",
    ):
        if token not in content_pack_non_video_media_probe:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused non-video probe lost a required validation boundary.",
                "Restore bounded audio, image and declarative validation without UI, network or process capability.",
            )
    for token in (
        "import AppKit",
        "import SwiftUI",
        "import Network",
        "URLSession",
        "Process(",
        "FileManager.default",
        "AVAssetImageGenerator(",
        "AVAssetReader(",
    ):
        if token in content_pack_non_video_media_probe:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The focused non-video probe gained UI, network, process, broad storage or video-frame capability.",
                "Keep the module limited to bounded audio, image and declarative validation.",
            )

    if "ContentPackMediaQualityProbe().probe(" not in content_pack_video_media_probe:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The focused video probe no longer delegates bounded checkpoint and timeline validation.",
            "Restore ContentPackMediaQualityProbe delegation after first-frame and codec validation.",
        )
    for token in (
        "AVAssetReader(",
        "kCVPixelBufferPixelFormatTypeKey",
        "kAudioFormatLinearPCM",
        "ContentPackMediaQualityPolicy.timelineAlignment(",
    ):
        if token in content_pack_media_probe:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Deep media decoding or timeline policy was merged into the media router.",
                "Keep timeline policy in ContentPackMediaQualityProbe.swift and bounded sample decoding in ContentPackMediaCheckpointDecoder.swift.",
            )

    for source_path in sorted(app.glob("*.swift")):
        if source_path.name == "ContentPackMediaProbe.swift":
            continue
        source_text = regular_text(
            source_path,
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "App source",
        )
        if "AVFoundationContentPackVideoMediaProbe(" in source_text:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The focused video-probe implementation is constructed outside the media router.",
                "Keep AVFoundationContentPackMediaProbe as the sole owner of concrete video/non-video probe composition.",
            )
    for token in (
        "struct ContentPackMediaQualityProbe",
        "enum ContentPackMediaQualityPolicy",
        "maximumTimelineOffsetMs = 250",
        "ContentPackMediaCheckpointDecoder()",
        "checkpoint: .midpoint",
        "checkpoint: .tail",
        "timelineAlignment(",
    ):
        if token not in content_pack_media_quality_probe:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The media quality probe lost checkpoint orchestration or timeline policy.",
                "Restore midpoint/tail orchestration and the 250ms timeline envelope, then retry.",
            )
    for token in (
        "AVAssetReader(",
        "reader.timeRange = CMTimeRange(",
        "kCVPixelBufferPixelFormatTypeKey",
        "kAudioFormatLinearPCM",
        "copyNextSampleBuffer()",
    ):
        if token in content_pack_media_quality_probe:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Low-level checkpoint decoding was merged back into the media quality policy probe.",
                "Keep AVAssetReader setup and decoded-sample mechanics in ContentPackMediaCheckpointDecoder.swift.",
            )
    for token in (
        "import AppKit",
        "import SwiftUI",
        "import Network",
        "URLSession",
        "Process(",
        "ContentPackStore",
        "ContentPackValidator.sha256(",
        "FileManager.default",
    ):
        if token in content_pack_media_quality_probe:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The bounded media quality probe gained UI, network, process, storage or hashing capability.",
                "Keep it read-only, AVFoundation-only and outside the playback hot path.",
            )

    for token in (
        "struct ContentPackMediaCheckpointDecoder",
        "windowSeconds = 0.45",
        "AVAssetReader(",
        "reader.timeRange = CMTimeRange(",
        "kCVPixelBufferPixelFormatTypeKey",
        "kAudioFormatLinearPCM",
        "copyNextSampleBuffer()",
        "CMSampleBufferDataIsReady",
        ".checkpointDecodeFailed",
    ):
        if token not in content_pack_media_checkpoint_decoder:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The media checkpoint decoder lost a bounded decoded-sample responsibility.",
                "Restore the sub-second AVAssetReader window and stable checkpoint failure mapping, then retry.",
            )
    for token in (
        "ContentPackMediaQualityPolicy.timelineAlignment(",
        "maximumTimelineOffsetMs",
        " async ",
        " await ",
        "import AppKit",
        "import SwiftUI",
        "import Network",
        "URLSession",
        "Process(",
        "ContentPackStore",
        "ContentPackValidator.sha256(",
        "FileManager.default",
    ):
        if token in content_pack_media_checkpoint_decoder:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The media checkpoint decoder gained timeline policy, concurrency, UI, network, process, storage or hashing capability.",
                "Keep the decoder synchronous, read-only and limited to bounded AVFoundation sample mechanics.",
            )

    if not re.search(
        r"\bfinal\s+class\s+CompanionLifestyleRuntimeCoordinator\b",
        lifestyle_runtime,
    ) or "CompanionLifestyleMemoryAdapter" not in lifestyle_runtime \
            or "CompanionLifestyleScheduler(" not in lifestyle_runtime:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The focused lifestyle runtime lost memory or scheduler coordination.",
            "Restore the focused runtime coordinator and keep bounded system facts in the view model.",
        )
    for token in (
        "CompanionLifestyleMemoryAdapter",
        "CompanionLifestyleScheduler(",
        "lifestyleSessionStartedAt",
        "lifestyleWasUserRecentlyActive",
        "lifestyleReturnedAt",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Lifestyle memory or scheduling state was merged back into the view model.",
                "Keep session recovery and scheduler orchestration in CompanionLifestyleRuntimeCoordinator.swift.",
            )

    if not re.search(
        r"\bfinal\s+class\s+CompanionSharedDayRuntimeCoordinator\s*:\s*ObservableObject\b",
        shared_day_runtime,
    ) or "let workday: CompanionWorkdayRuntimeCoordinator" not in shared_day_runtime \
            or "let lifestyle: CompanionLifestyleRuntimeCoordinator" not in shared_day_runtime \
            or "private var careTask: Task<Void, Never>?" not in shared_day_runtime \
            or "private var careGeneration: UInt64 = 0" not in shared_day_runtime \
            or "func evaluateCare(" not in shared_day_runtime \
            or "func stop()" not in shared_day_runtime:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The shared-day composition root lost its bounded care/work lifecycle.",
            "Restore CompanionSharedDayRuntimeCoordinator and keep only semantic presentation effects in the view model.",
        )
    for token in (
        "AVPlayer",
        "NSWindow",
        "VoicePackPlayer",
        "taskTitle",
        "prompt",
        "sourceCode",
        "absolutePath",
    ):
        if token in shared_day_runtime:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The shared-day coordinator gained private task or presentation detail.",
                "Pass bounded activity/preferences facts and return semantic receipts only.",
            )
    if "private let sharedDayRuntime: CompanionSharedDayRuntimeCoordinator" not in view_model \
            or "sharedDayRuntime.start(" not in view_model \
            or "sharedDayRuntime.evaluateCare(" not in view_model:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The view model bypasses the unified shared-day composition root.",
            "Start care and trusted work polling through CompanionSharedDayRuntimeCoordinator.",
        )
    for token in (
        "private var reminderTask",
        "private func startReminderLoop",
        "private func startCompletionWatcher",
        "workdayRuntime.startPolling(",
        "lifestyleRuntime.evaluate(",
        "workdayRuntime.refreshDay(",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Split care/work clock ownership returned to the view model.",
                "Keep both cancellable lifecycles in CompanionSharedDayRuntimeCoordinator.",
            )

    for declaration in (
        "CompanionContentOperationKind",
        "CompanionContentOperationSuccess",
        "CompanionContentOperationReceipt",
        "CompanionContentRecoveryReceipt",
    ):
        if not re.search(
            rf"\b(?:enum|struct)\s+{declaration}\b",
            content_operation_models,
        ):
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused content operation models lost a required receipt type.",
                "Restore the operation and recovery receipt models in CompanionContentOperationModels.swift.",
            )
        if re.search(rf"\b(?:enum|struct)\s+{declaration}\b", content_operations):
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Content operation receipt models were merged back into the MainActor coordinator.",
                "Keep data-only operation and recovery receipts in CompanionContentOperationModels.swift.",
            )

    for declaration in (
        "ContentPackPlaybackReference",
        "CompanionVideoAsset",
        "ContentPackSelectionContext",
        "ContentPackVideoSelection",
        "CompanionVideoSequenceStep",
        "CompanionVideoSequence",
        "CompanionSequencePlaybackCursor",
        "ContentPackExperienceSelection",
    ):
        if not re.search(rf"\bstruct\s+{declaration}\b", playback_models):
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused content-pack playback models lost a required immutable type.",
                "Restore playback values and cursor state in ContentPackPlaybackModels.swift.",
            )
        if re.search(rf"\bstruct\s+{declaration}\b", runtime_catalog) \
                or re.search(rf"\bstruct\s+{declaration}\b", runtime_selection):
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Playback values or cursor state were merged back into runtime selection policy.",
                "Keep immutable playback models in ContentPackPlaybackModels.swift, manifest projection in ContentPackRuntimeCatalog.swift and selection policy in ContentPackRuntimeSelection.swift.",
            )

    for token in (
        "func selectExperience(",
        "func selectVideo(",
        "private static func isCoolingDown(",
        "private static func bestLocaleMatches<Value>(",
        "CompanionLocaleResolutionPolicy.compatibilityScore(",
        "private struct ContentPackRandomSource",
    ):
        if token not in runtime_selection:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused runtime selection policy lost locale, cooldown or weighted-choice behavior.",
                "Restore pure caller-memory-driven selection in ContentPackRuntimeSelection.swift.",
            )
        if token in runtime_catalog:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Selection policy was merged back into manifest projection.",
                "Keep catalog construction in ContentPackRuntimeCatalog.swift and pure selection in ContentPackRuntimeSelection.swift.",
            )
    if "init(activePacks: [InstalledContentPack])" not in runtime_catalog \
            or "init(activePacks: [InstalledContentPack])" in runtime_selection:
        fail(
            "CORE_BOUNDARY_LAYER_VIOLATION",
            "Manifest projection and runtime selection no longer have distinct ownership.",
            "Keep installed-pack projection in ContentPackRuntimeCatalog.swift and selection algorithms in ContentPackRuntimeSelection.swift.",
        )

    if not re.search(
        r"\bfinal\s+class\s+CompanionContentOperationsCoordinator\s*:\s*ObservableObject\b",
        content_operations,
    ) or "private let library: CompanionContentLibrary" not in content_operations \
            or "private let backupOperations: CompanionBackupOperationsCoordinator" not in content_operations \
            or "startAccessingSecurityScopedResource()" not in content_operations:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The focused content operations coordinator lost transaction state or scoped access.",
            "Restore the focused coordinator and keep content transactions outside the view model.",
        )
    for token in (
        "final class CompanionBackupOperationsCoordinator: ObservableObject",
        "@Published private(set) var operationInProgress",
        "@Published private(set) var pendingPreview",
        "func exportBackup(",
        "func inspectBackup(",
        "func restoreInspectedBackup()",
        "startAccessingSecurityScopedResource()",
    ):
        if token not in backup_operations:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused backup coordinator lost scoped export, preflight or confirmed restore ownership.",
                "Restore portable-backup lifecycle state in CompanionBackupOperationsCoordinator.swift.",
            )
    for token in (
        "let manifest = try await library.exportBackup(",
        "let manifest = try await library.inspectBackup(",
        "let snapshot = try await library.restoreBackup(",
    ):
        if token in content_operations:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Portable-backup lifecycle was merged back into content-pack coordination.",
                "Keep backup export, preflight and confirmed restore in CompanionBackupOperationsCoordinator.swift.",
            )
    for token in (
        "enum CompanionContentOperationReceiptFactory",
        "static func success(",
        "static func failure(",
        "CompanionErrorPresentation.message(for: error)",
        "private static func contextualError(",
    ):
        if token not in content_operation_receipts:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The shared path-safe content operation receipt projection is incomplete.",
                "Restore receipt and localized error projection in CompanionContentOperationReceiptFactory.swift.",
            )
        if token in content_operations or token in backup_operations:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Path-safe receipt projection was duplicated into a stateful coordinator.",
                "Keep shared receipt construction in CompanionContentOperationReceiptFactory.swift.",
            )
    for token in (
        "private let contentLibrary: CompanionContentLibrary",
        "CompanionContentLibrary(",
        "startAccessingSecurityScopedResource()",
        "lastContentPackRemovalReceipt",
        "contentPackOperationInProgress = true",
        "backupOperationInProgress = true",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Content transaction state or filesystem access was merged back into the view model.",
                "Keep install, rollback, recoverable removal and backup scope in CompanionContentOperationsCoordinator.swift.",
            )

    if not re.search(
        r"\bfinal\s+class\s+CompanionMicrogameRuntimeCoordinator\s*:\s*ObservableObject\b",
        microgame_runtime,
    ) or "@Published private(set) var session = CompanionMicrogameSession()" not in microgame_runtime \
            or "private var timelineTask: Task<Void, Never>?" not in microgame_runtime \
            or "CompanionMicrogameReturnContext" not in microgame_runtime:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The focused microgame runtime lost exclusive session, timeline or return-context ownership.",
            "Restore the focused runtime coordinator and keep only presentation side effects in the view model.",
        )
    for token in (
        "@Published private var microgameSession",
        "microgameSession.start(",
        "microgameSession.tick()",
        "microgameSession.end()",
        "private var catchGameTask",
        "private var hideGameTask",
        "private var comboGameTask",
        "private var heartTraceGameTask",
        "private var rhythmGameTask",
        "private var feedGameTask",
        "catchGameReturnMode",
        "hideGameReturnMode",
        "comboGameReturnMode",
        "heartTraceGameReturnMode",
        "rhythmGameReturnMode",
        "feedGameReturnMode",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Microgame timeline or return-context ownership was merged back into the view model.",
                "Keep the single ephemeral session and cancellable timeline in CompanionMicrogameRuntimeCoordinator.swift.",
            )

    for token in (
        "enum CompanionMicrogamePresentation",
        "static func hudText(for session: CompanionMicrogameSession)",
        "extension CompanionViewModel",
        "CompanionMicrogamePresentation.hudText(for: microgameSession)",
        "var activePetGameHUDText: String",
        "var petGameActive: Bool",
    ):
        if token not in microgame_presentation:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused microgame presentation projection lost a required read-only binding.",
                "Restore the Core-session HUD projection in CompanionMicrogamePresentation.swift and retry.",
            )
    for token in (
        "var activePetGameHUDText",
        '"game.hud.feed"',
        '"game.hud.comboSteps"',
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Microgame HUD or read-only game projection was merged back into the view model.",
                "Keep localized game state projection in CompanionMicrogamePresentation.swift.",
            )
    for token in (
        "import AppKit",
        "import SwiftUI",
        "UserDefaults",
        "VoicePackPlayer",
        "NSHapticFeedbackManager",
        "CGEvent",
        "NSWindow",
        "Task {",
        "microgameRuntime",
    ):
        if token in microgame_presentation:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The read-only microgame presentation projection gained a runtime or platform side effect.",
                "Move timers, audio, haptics, windows and persistence back to their focused App coordinators.",
            )

    for token in (
        "enum CompanionMicrogameCompletionPresenter",
        "static func presentation(",
        "for plan: CompanionMicrogameCompletionPlan",
        "allowsRomanticGestures: Bool",
    ):
        if token not in microgame_completion_presentation:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused microgame completion projection lost a required semantic binding.",
                "Restore the localized Core-plan projection before changing reward presentation.",
            )
    for token in (
        "import AppKit",
        "import SwiftUI",
        "UserDefaults",
        "VoicePackPlayer",
        "NSHapticFeedbackManager",
        "CGEvent",
        "NSWindow",
        "Task {",
        "microgameRuntime",
    ):
        if token in microgame_completion_presentation:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The microgame completion projection gained a runtime or platform side effect.",
                "Keep it as a localized semantic projection and leave side effects in focused App coordinators.",
            )
    for token in (
        '"game.catch.won"',
        '"game.hide.won"',
        '"game.combo.won"',
        '"game.trace.won"',
        '"game.rhythm.won"',
        '"game.feed.won"',
        '"status.game.catch.complete"',
        '"status.game.feed.ended"',
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Microgame completion or reward policy was duplicated back into the view model.",
                "Keep relationship rewards in Core and localized completion copy in the focused App projection.",
            )
    for token in (
        "private func finishMicrogame(",
        "CompanionMicrogameCompletionPolicy().plan(",
        "CompanionMicrogameCompletionPresenter.presentation(",
    ):
        if token not in view_model:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The view model lost the unified microgame completion handoff.",
                "Restore the single Core-plan to App-presentation completion path.",
            )

    for token in (
        "struct CompanionTaskCompletionPresentation",
        "static func celebration(",
        "static func reply(",
        "CompanionTaskCompletionPolicy.celebration(",
        "CompanionTaskCompletionPolicy.reply(",
    ):
        if token not in task_completion_presentation:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused task-completion projection lost a required semantic binding.",
                "Restore the localized Core-plan projection before changing completion or reply presentation.",
            )
    for token in (
        "import AppKit",
        "import SwiftUI",
        "UserDefaults",
        "VoicePackPlayer",
        "NSHapticFeedbackManager",
        "NSWindow",
        "Task {",
        "workdayRuntime",
        "relationshipRuntime",
    ):
        if token in task_completion_presentation:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The task-completion presentation projection gained runtime, persistence or platform side effects.",
                "Keep it as a localized semantic projection and perform side effects in focused App coordinators.",
            )
    for token in (
        "private enum CompletionReplyStyle",
        "private func completionReplyAction(",
        "private func completionAction(",
        "private func completionLine(",
        '"reply.long-press"',
        '"reply.singleTap"',
        '"reply.doubleTap"',
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Task-completion celebration or reply policy was duplicated back into the view model.",
                "Keep tier, tone ceiling, relationship reward and copy intent in the focused Core/App completion modules.",
            )
    for token in (
        "CompanionTaskCompletionPresentation.celebration(",
        "CompanionTaskCompletionPolicy.reply(",
        "private func applyCompletionReply(",
    ):
        if token not in view_model:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The view model lost the unified task-completion presentation or reply handoff.",
                "Restore the single Core policy to side-effect-free presentation binding.",
            )

    for token in (
        "struct CompanionPetDragPresentation",
        "static func presentation(",
        "switch plan.feedback",
        "case .fling:",
        "case .dock:",
        "case .lift:",
        "case .nudge:",
        "case .settle:",
    ):
        if token not in pet_drag_presentation:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused pet-drag projection lost a semantic feedback binding.",
                "Restore the complete Core-plan to localized App presentation mapping.",
            )
    for token in (
        "import AppKit",
        "import SwiftUI",
        "UserDefaults",
        "NSHapticFeedbackManager",
        "NSWindow",
        "Task {",
        "playInteractionCue(",
        "recordRelationshipMoment(",
    ):
        if token in pet_drag_presentation:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The pet-drag presentation projection gained a runtime or platform side effect.",
                "Keep it as a localized value projection and perform effects in the App composition root.",
            )
    drag_start = view_model.find("func handlePetDragEnded(")
    drag_end = view_model.find("func playAction(", drag_start)
    if drag_start < 0 or drag_end < 0:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The App lost its bounded direct-manipulation handoff.",
            "Restore handlePetDragEnded and delegate final feedback to the Core policy.",
        )
    drag_handoff = view_model[drag_start:drag_end]
    for token in (
        "CompanionPetDragPolicy.plan(",
        "CompanionPetDragPresentation.presentation(",
        "recordRelationshipMoment(dragPlan.relationshipMomentKey)",
        "schedulePoseReset(after: dragPlan.poseResetDelay)",
    ):
        if token not in drag_handoff:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The App lost the unified pet-drag policy or presentation handoff.",
                "Restore one Core plan, one side-effect-free projection and one bounded effect commit.",
            )
    for token in (
        "cue = .petFling",
        "cue = .petDock",
        "cue = .petLift",
        "cue = .petNudge",
        "cue = .petSettle",
        'symbol: "tornado"',
        '"interaction.fling"',
    ):
        if token in drag_handoff:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Pet-drag classification or presentation policy was duplicated back into the view model.",
                "Keep thresholds and semantic mapping in the focused Core/App drag modules.",
            )

    for token in (
        "struct CompanionRuntimeSupportSnapshot",
        "enum CompanionRuntimeSupport",
        "CompanionRuntimeReadiness.evaluate(facts)",
        "CompanionRuntimeReadiness.safeRecoveryActions(checks)",
    ):
        if token not in runtime_support:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The runtime support projection lost its bounded Core delegation.",
                "Restore the privacy-minimal support snapshot and Core readiness evaluation.",
            )
    for token in (
        "final class CompanionRuntimeRepairCoordinator: ObservableObject",
        "@Published private(set) var snapshot",
        "@Published private(set) var isRepairing",
        "@Published private(set) var message",
        "private var contentLibraryHealthy",
        "workdayRuntime.repairEventBridge()",
        "recoverInterruptedInstalls()",
        "guard !Task.isCancelled",
    ):
        if token not in runtime_repair:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The focused runtime repair coordinator lost bounded state or cancellation ownership.",
                "Restore refresh/repair ownership in CompanionRuntimeRepairCoordinator.swift.",
            )
    for token in (
        "import AppKit",
        "import SwiftUI",
        "UserDefaults",
        "NSPasteboard",
        "NSWorkspace",
        "URLSession",
        "Process(",
        "removeItem(",
        "moveItem(",
        "replaceItemAt(",
    ):
        if token in runtime_repair:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The bounded runtime repair coordinator gained an unsafe platform or destructive side effect.",
                "Keep it limited to event-bridge repair and transactional content recovery.",
            )
    for token in (
        "extension CompanionViewModel",
        "var runtimeReadinessSummary: String",
        "var runtimeReadinessChecks: [CompanionRuntimeReadinessCheck]",
        "var runtimeSafeRepairAvailable: Bool",
        "func runtimeReadinessTitle(",
        "func runtimeReadinessDetail(",
    ):
        if token not in runtime_readiness_presentation:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The read-only runtime readiness presentation lost a required Settings projection.",
                "Restore the localized projection in CompanionRuntimeReadinessPresentation.swift.",
            )
    for token in (
        "import AppKit",
        "import SwiftUI",
        "UserDefaults",
        "Task {",
        "repairEventBridge",
        "recoverInterruptedInstalls",
    ):
        if token in runtime_readiness_presentation:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The read-only runtime readiness presentation gained a repair or platform side effect.",
                "Keep Settings copy projection read-only and delegate repairs to the coordinator.",
            )
    for token in (
        "private let runtimeRepair = CompanionRuntimeRepairCoordinator()",
        "runtimeRepair.objectWillChange.sink",
        "runtimeRepair.refresh(",
        "runtimeRepair.repair(",
        "runtimeRepair.rebuild(",
    ):
        if token not in view_model:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The App composition root lost its focused runtime-repair binding.",
                "Restore one observed coordinator and delegate refresh, repair and rebuild calls.",
            )
    for token in (
        "@Published private(set) var runtimeSupportSnapshot",
        "@Published private(set) var runtimeRepairInProgress",
        "@Published private(set) var runtimeRepairMessage",
        "private var contentLibraryHealthy",
        "var runtimeReadinessSummary: String",
        "func runtimeReadinessTitle(",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Runtime health state or Settings projection was merged back into the view model.",
                "Keep repair state in CompanionRuntimeRepairCoordinator and copy in the presentation extension.",
            )

    if not re.search(
        r"\bfinal\s+class\s+CompanionExperienceRuntimeCoordinator\s*<",
        experience_runtime,
    ) or "private var director: CompanionExperienceDirector" not in experience_runtime \
            or "CompanionExperiencePresentationToken" not in experience_runtime \
            or "private var presentationTask: Task<Void, Never>?" not in experience_runtime \
            or "private var replayTask: Task<Void, Never>?" not in experience_runtime \
            or "private var handoffTask: Task<Void, Never>?" not in experience_runtime \
            or "func noteUserInitiated(" not in experience_runtime \
            or "case coalescedTrustedTerminal" not in experience_runtime:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The focused experience runtime lost arbitration, direct-play grace, token, queue or handoff ownership.",
            "Restore the unified experience runtime and its timestamp-only direct-play grace while keeping presentation side effects in the view model.",
        )
    for token in (
        "private var eventTask",
        "pendingPriorityEvents",
        "PendingCompanionEvent",
        "private var experienceDirector",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Experience arbitration, lifetime or trusted queue ownership was merged back into the view model.",
                "Keep generation-safe presentation and pending terminal replay in CompanionExperienceRuntimeCoordinator.swift.",
            )

    if not re.search(
        r"\bfinal\s+class\s+CompanionWorkdayRuntimeCoordinator\s*:\s*ObservableObject\b",
        workday_runtime,
    ) or "private let adapter: CompanionWorkdayAdapter" not in workday_runtime \
            or "private let watcher: CodexCompletionWatcher" not in workday_runtime \
            or "private var pollingTask: Task<Void, Never>?" not in workday_runtime \
            or "private var replyTask: Task<Void, Never>?" not in workday_runtime \
            or "CompanionWorkdayExperiencePolicy.plan(" not in workday_runtime:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The focused workday runtime lost state, watcher, policy or reply-lifetime ownership.",
            "Restore the unified workday coordinator and keep only semantic presentation side effects in the view model.",
        )
    for token in (
        "private let completionWatcher",
        "private let workdayAdapter",
        "private var completionTask",
        "private var completionReplyTask",
        "private var completionReplyDeadline",
        "workdayAdapter.consume(",
        "CompanionWorkdayExperiencePolicy.plan(",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Workday polling, persistence, trust projection or reply lifetime was merged back into the view model.",
                "Keep the cancellable workday loop and generation-safe reply window in CompanionWorkdayRuntimeCoordinator.swift.",
            )

    for token in (
        "enum CompanionWorkdayApplicationProjection",
        "struct CompanionWorkdayApplicationPlan",
        "enum CompanionWorkdayApplicationEvent",
        "relationship: isCompletion",
        "visual != .completed || allowsCompleted",
    ):
        if token not in workday_application_projection:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The completion-safe workday App projection lost its semantic gate.",
                "Restore the side-effect-free projection and keep non-terminal signals from creating completion effects.",
            )
    for token in (
        "URLSession", "UserDefaults", "FileManager", "AVPlayer",
        "NSWindow", "VoicePackPlayer", "Task {", "Process(",
    ):
        if token in workday_application_projection:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The workday App projection gained a side-effect capability.",
                "Keep workday application projection value-only and execute effects in the composition root.",
            )
    if "CompanionWorkdayApplicationProjection.project(" not in view_model:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The view model bypasses the completion-safe workday application projection.",
            "Route every semantic workday presentation through CompanionWorkdayApplicationProjection before executing effects.",
        )
    for token in (
        "presentation.visual", "presentation.relationshipReward",
        "switch presentation.event",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Raw workday semantic mapping was merged back into the view model.",
                "Keep completion-only sanitization in CompanionWorkdayApplicationProjection.swift.",
            )

    if not re.search(
        r"\bfinal\s+class\s+CompanionFirstSessionRuntimeCoordinator\s*:\s*ObservableObject\b",
        first_session_runtime,
    ) or "@Published private(set) var journey = CompanionFirstSessionJourney()" not in first_session_runtime \
            or "private var workArcTask: Task<Void, Never>?" not in first_session_runtime \
            or "private var generation: UInt64 = 0" not in first_session_runtime:
        fail(
            "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
            "The focused first-session runtime lost journey, timing or stale-task ownership.",
            "Restore the local-only coordinator and keep preview timing outside the view model.",
        )
    for token in (
        "private var workArcPreviewTask",
        "Task.sleep(nanoseconds: 1_400_000_000)",
        "Task.sleep(nanoseconds: 1_800_000_000)",
    ):
        if token in view_model:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "First-session or simulated work-arc timing was merged back into the view model.",
                "Keep cancellable preview timing in CompanionFirstSessionRuntimeCoordinator.swift.",
            )

    focused_app_modules: dict[str, dict[str, int]] = {}
    for name, maximum in FOCUSED_APP_MODULE_BUDGETS.items():
        count = line_count(
            regular_text(
                app / name,
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "focused App module",
            )
        )
        if count > maximum:
            fail(
                "CORE_BOUNDARY_FOCUSED_MODULE_BUDGET_EXCEEDED",
                "A focused App module grew beyond its reviewable size budget.",
                "Split the focused adapter or model by responsibility, then rerun the audit.",
            )
        focused_app_modules[name] = {"lines": count, "absoluteMaxLines": maximum}

    content_pack_validator = regular_text(
        app / "ContentPack.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack validator",
    )
    for declaration in (
        "ContentPackManifest",
        "CompanionFailureReceipt",
        "SemanticVersion",
    ):
        if re.search(rf"\b(?:struct|enum|class|protocol)\s+{declaration}\b", content_pack_validator):
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "A focused content-pack contract was merged back into the validator.",
                "Keep manifest models, failure receipts and semantic-version parsing in their focused source files.",
            )

    manifest_field_validator = regular_text(
        app / "ContentPackManifestFieldValidator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack manifest field validator",
    )
    contribution_validator = regular_text(
        app / "ContentPackContributionValidator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack contribution orchestrator",
    )
    contribution_support = regular_text(
        app / "ContentPackContributionValidationSupport.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack contribution validation support",
    )
    rights_validator = regular_text(
        app / "ContentPackRightsValidator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack rights validator",
    )
    accessibility_validator = regular_text(
        app / "ContentPackAccessibilityValidator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack accessibility validator",
    )
    fallback_validator = regular_text(
        app / "ContentPackFallbackValidator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack fallback validator",
    )
    package_contents_validator = regular_text(
        app / "ContentPackPackageContentsValidator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack package-contents validator",
    )
    asset_file_validator = regular_text(
        app / "ContentPackAssetFileValidator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack asset-file validator",
    )
    asset_projection_validator = regular_text(
        app / "ContentPackAssetProjectionValidator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack asset-projection validator",
    )
    asset_validator = regular_text(
        app / "ContentPackAssetValidator.swift",
        "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
        "content-pack asset validation dispatcher",
    )
    for token in (
        "ContentPackManifestFieldValidator.validate(manifestData)",
        "ContentPackContributionValidator().validate(",
        "ContentPackAssetValidator(fileManager: fileManager)",
        "assetValidator.validate(asset, packageRoot: root)",
        "assetValidator.validatePackageContents(",
    ):
        if token not in content_pack_validator:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The content-pack orchestrator lost a focused validation delegation.",
                "Restore raw-field, contribution and asset/filesystem delegation in ContentPack.swift.",
            )
    for token in (
        "JSONSerialization.jsonObject",
        "unknownManifestField",
        "privatePathInContribution",
        "strictRightsMetadataMissing",
        "strictAccessibilityMetadataMissing",
        "strictFallbackMetadataMissing",
        "resourceValues(",
        "isExecutableFile(",
        "safeAreaNotVisible",
    ):
        if token in content_pack_validator:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Focused content-pack validation policy was merged back into the orchestrator.",
                "Keep raw JSON shape, contribution contract and asset/filesystem checks in their focused validators.",
            )
    for token in (
        "JSONSerialization.jsonObject",
        "unknownManifestField",
        "rejectUnknownKeys(",
        "<invalid-key>",
    ):
        if token not in manifest_field_validator:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The raw content-pack field validator lost fail-closed shape checking.",
                "Restore bounded unknown-field rejection before Codable decoding.",
            )
    for token in (
        "private let rightsValidator = ContentPackRightsValidator()",
        "private let accessibilityValidator = ContentPackAccessibilityValidator()",
        "private let fallbackValidator = ContentPackFallbackValidator()",
        "try rightsValidator.validate(",
        "try accessibilityValidator.validate(",
        "try fallbackValidator.validate(",
    ):
        if token not in contribution_validator:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The contribution orchestrator lost a focused v2 policy delegation.",
                "Restore rights, accessibility and fallback delegation without remerging their rules.",
            )
    for source, label, tokens in (
        (
            contribution_support,
            "shared contribution field policy",
            (
                "privatePathInContribution",
                "invalidPackageContributionField",
                "invalidRightsField",
                "invalidAccessibilityField",
                "evidenceIdentifierPattern",
            ),
        ),
        (
            rights_validator,
            "rights policy",
            (
                "strictPackageMetadataMissing",
                "strictRightsMetadataMissing",
                "validatePackageProvenance(",
                "validateStrictRights(",
            ),
        ),
        (
            accessibility_validator,
            "accessibility policy",
            (
                "strictAccessibilityMetadataMissing",
                "validateStrictAccessibility(",
                "validateLocalizedAccessibility(",
            ),
        ),
        (
            fallback_validator,
            "fallback policy",
            (
                "strictFallbackMetadataMissing",
                "invalidAssetFallback",
                "duplicateFallbackAsset",
            ),
        ),
    ):
        for token in tokens:
            if token not in source:
                fail(
                    "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                    f"The focused content-pack {label} lost a required invariant.",
                    "Restore the invariant in its focused pure validator and keep orchestration thin.",
                )
    for token in (
        "strictPackageMetadataMissing",
        "strictRightsMetadataMissing",
        "strictAccessibilityMetadataMissing",
        "strictFallbackMetadataMissing",
        "privatePathInContribution",
        "invalidAssetFallback",
    ):
        if token in contribution_validator:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Focused contribution policy was merged back into its orchestrator.",
                "Keep the contribution orchestrator limited to contract dispatch and focused policy delegation.",
            )
    for token in (
        "private let packageContentsValidator: ContentPackPackageContentsValidator",
        "private let assetFileValidator: ContentPackAssetFileValidator",
        "private let projectionValidator = ContentPackAssetProjectionValidator()",
        "try packageContentsValidator.validate(",
        "try assetFileValidator.validate(asset, packageRoot: packageRoot)",
        "try projectionValidator.validate(asset)",
    ):
        if token not in asset_validator:
            fail(
                "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                "The asset validation dispatcher lost a focused delegation.",
                "Restore package enumeration, asset-file authentication and pure projection delegation without remerging their rules.",
            )
    for source, label, tokens in (
        (
            package_contents_validator,
            "package-contents policy",
            (
                "fileManager.enumerator(",
                "hiddenPathNotAllowed",
                "caseInsensitivePathCollision",
                "symbolicLinkNotAllowed",
                "hardLinkNotAllowed",
                "undeclaredFile",
                "maximumFileCount",
                "maximumUnpackedBytes",
            ),
        ),
        (
            asset_file_validator,
            "asset-file policy",
            (
                "invalidAssetPath",
                "resolvingSymlinksInPath",
                "fileExists(",
                "maximumSingleAssetBytes",
                "isExecutableFile(",
                "ContentPackValidator.sha256(",
                "hashMismatch",
            ),
        ),
        (
            asset_projection_validator,
            "asset-projection policy",
            (
                "invalidVideoMetadata",
                "maximumMediaDurationMs",
                "invalidCropAnchor",
                "validateFocalTracks(",
                "validateSafeAreas(",
                "safeAreaNotVisible",
                "ContentPackTriggerContract.isAllowed",
            ),
        ),
    ):
        for token in tokens:
            if token not in source:
                fail(
                    "CORE_BOUNDARY_REQUIRED_PATH_MISSING",
                    f"The focused content-pack {label} lost a required invariant.",
                    "Restore the invariant in its focused validator and keep the dispatcher thin.",
                )
    for token in (
        "fileManager.enumerator(",
        "hardLinkNotAllowed",
        "isExecutableFile(",
        "ContentPackValidator.sha256(",
        "safeAreaNotVisible",
        "validateFocalTracks(",
    ):
        if token in asset_validator:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Package, file/hash or projection policy was merged back into the asset dispatcher.",
                "Keep ContentPackAssetValidator limited to stable API adaptation and focused delegation.",
            )
    for source, label in (
        (manifest_field_validator, "raw field validator"),
        (contribution_validator, "contribution orchestrator"),
        (contribution_support, "shared contribution field policy"),
        (rights_validator, "rights validator"),
        (accessibility_validator, "accessibility validator"),
        (fallback_validator, "fallback validator"),
        (package_contents_validator, "package-contents validator"),
        (asset_file_validator, "asset-file validator"),
        (asset_projection_validator, "asset-projection validator"),
        (asset_validator, "asset validation dispatcher"),
    ):
        for token in (
            "URLSession", "Network", "SwiftUI", "AppKit", "AVFoundation",
            "UserDefaults", "Process(", "NSWorkspace", "Task {", "Task<",
        ):
            if token in source:
                fail(
                    "CORE_BOUNDARY_LAYER_VIOLATION",
                    f"The focused content-pack {label} gained an unrelated capability.",
                    "Keep validators synchronous, local and free of UI, network, process, media-playback and persistence capability.",
                )
    for token in (
        "FileManager", "Data(contentsOf:", "resourceValues(", "sha256(",
    ):
        if any(
            token in source
            for source in (
                manifest_field_validator,
                contribution_validator,
                contribution_support,
                rights_validator,
                accessibility_validator,
                fallback_validator,
            )
        ):
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "A pure content-pack policy validator gained filesystem or hashing capability.",
                "Keep raw-field and contribution validation value-only; filesystem and hash checks belong to the focused package and asset-file validators.",
            )
    for token in (
        "FileManager", "Data(contentsOf:", "resourceValues(", "sha256(",
        "fileExists(", "isExecutableFile(",
    ):
        if token in asset_projection_validator:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "The pure asset-projection validator gained filesystem or hashing capability.",
                "Keep projection checks value-only; package enumeration and asset authentication own filesystem access.",
            )
    for token in (
        "safeAreaNotVisible", "invalidFocalTrack", "invalidCropAnchor",
        "ContentPackTriggerContract.isAllowed", "maximumMediaDurationMs",
    ):
        if token in package_contents_validator or token in asset_file_validator:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Projection or media-declaration policy was merged into a filesystem validator.",
                "Keep projection, focal, safe-area and trigger rules in ContentPackAssetProjectionValidator.swift.",
            )
    for token in (
        "fileManager.enumerator(", "maximumFileCount", "maximumUnpackedBytes",
        "undeclaredFile", "hardLinkNotAllowed",
    ):
        if token in asset_file_validator:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Package-wide enumeration policy was merged into per-asset file authentication.",
                "Keep aggregate enumeration and declared-file rules in ContentPackPackageContentsValidator.swift.",
            )
    for token in (
        "ContentPackValidator.sha256(", "hashMismatch", "isExecutableFile(",
        "maximumSingleAssetBytes",
    ):
        if token in package_contents_validator:
            fail(
                "CORE_BOUNDARY_LAYER_VIOLATION",
                "Per-asset authentication policy was merged into package enumeration.",
                "Keep hashing, executable and single-asset size checks in ContentPackAssetFileValidator.swift.",
            )

    baseline_text = regular_text(root / BASELINE_RELATIVE, "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "Core boundary baseline")
    try:
        baseline = json.loads(baseline_text)
        with (root / "Info.plist").open("rb") as stream:
            app_version = str(plistlib.load(stream)["CFBundleShortVersionString"])
    except (json.JSONDecodeError, OSError, KeyError, plistlib.InvalidFileException):
        fail("CORE_BOUNDARY_BASELINE_INVALID", "The Core boundary baseline or application version is invalid.", "Restore the versioned baseline and Info.plist, then retry.")
    if (
        not isinstance(baseline, dict)
        or set(baseline) != {"schemaVersion", "contract", "appVersion", "policy", "files"}
        or baseline.get("schemaVersion") != 1
        or baseline.get("contract") != "chengyin.core-module-boundary-baseline/v1"
        or baseline.get("appVersion") != app_version
        or baseline.get("policy") != "nonIncreasingUntilSplit"
        or not isinstance(baseline.get("files"), dict)
        or set(baseline["files"]) != set(COMPOSITION_FILES)
    ):
        fail("CORE_BOUNDARY_BASELINE_INVALID", "The Core boundary baseline contract is stale or malformed.", "Refresh it only after a reviewed migration and keep the application version aligned.")

    composition: dict[str, dict[str, object]] = {}
    composition_state = "WITHIN_BUDGET"
    for name in COMPOSITION_FILES:
        record = baseline["files"].get(name)
        if (
            not isinstance(record, dict)
            or set(record) != {"baselineLines", "absoluteMaxLines"}
            or isinstance(record.get("baselineLines"), bool)
            or not isinstance(record.get("baselineLines"), int)
            or isinstance(record.get("absoluteMaxLines"), bool)
            or not isinstance(record.get("absoluteMaxLines"), int)
            or not 1 <= record["baselineLines"] <= record["absoluteMaxLines"] <= 20_000
        ):
            fail("CORE_BOUNDARY_BASELINE_INVALID", "A composition baseline record is invalid.", "Restore positive bounded line budgets and retry.")
        baseline_lines = record["baselineLines"]
        absolute_max = record["absoluteMaxLines"]
        count = line_count(regular_text(app / name, "CORE_BOUNDARY_REQUIRED_PATH_MISSING", "App composition source"))
        if count > absolute_max:
            fail("CORE_BOUNDARY_COMPOSITION_BUDGET_EXCEEDED", "An App composition migration surface grew beyond its frozen budget.", "Extract deterministic policy or focused presentation into a separate tested file.")
        if count > baseline_lines:
            fail(
                "CORE_BOUNDARY_MONOTONIC_BUDGET_EXCEEDED",
                f"{name} has {count} lines, above its versioned {baseline_lines}-line baseline.",
                "Remove or extract at least the added lines; baseline increases require a separately reviewed architecture migration.",
            )
        remaining = absolute_max - count
        remaining_percent = round((remaining / absolute_max) * 100, 2)
        saturation = "near-saturation" if remaining_percent <= 2 else "within-budget"
        if saturation == "near-saturation":
            composition_state = "NEAR_SATURATION"
        composition[name] = {
            "lines": count,
            "baselineLines": baseline_lines,
            "absoluteMaxLines": absolute_max,
            "remainingLines": remaining,
            "remainingPercent": remaining_percent,
            "saturation": saturation,
            "deltaFromBaseline": count - baseline_lines,
        }

    return {
        "schemaVersion": "chengyin.core-boundaries-audit/v1",
        "status": "PASS",
        "coreModule": "CompanionContracts",
        "appModule": "CompanionApp",
        "coreSourceFileCount": len(swift_files),
        "requiredPolicyCount": len(REQUIRED_CORE_POLICIES),
        "requiredPolicyLines": dict(sorted(policy_lines.items())),
        "allowedCoreImports": sorted(observed_imports),
        "composition": composition,
        "compositionBudgetState": composition_state,
        "focusedAppModules": focused_app_modules,
        "migrationPolicy": "non-increasing per version until the composition surface is split",
        "proofStrength": "source-regex-and-token-guard-not-compiler-ast",
        "packageDependencyEvidence": "bounded Package.swift source-window check",
        "evaluatedPackageGraphContract": "chengyin.swiftpm-package-graph/v1-required-by-doctor-ci-and-source-package",
        "compilerParserBoundaryContract": "chengyin.swift-compiler-boundaries/v1-required-by-doctor-ci-contributor-and-source-package",
        "futureHardeningCandidates": [
            "SwiftSyntax semantic policy audit",
            "compiler typechecked dependency scan",
            "continued monotonic composition-budget reduction",
        ],
        "networkRequired": False,
    }


def failure_receipt(error: BoundaryFailure) -> dict[str, object]:
    return {
        "schemaVersion": "chengyin.core-boundaries-audit/v1",
        "status": "FAIL",
        "code": error.code,
        "message": error.message,
        "recoveryAction": error.action,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=pathlib.Path, default=DEFAULT_ROOT)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        receipt = audit(args.root.resolve())
    except BoundaryFailure as error:
        receipt = failure_receipt(error)
        if args.json:
            print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
        else:
            print(f"FAIL  [{error.code}] {error.message}", file=sys.stderr)
            print(f"ACTION  {error.action}", file=sys.stderr)
        return 1
    except Exception:
        receipt = failure_receipt(BoundaryFailure(
            "CORE_BOUNDARY_UNEXPECTED_ERROR",
            "The Core boundary audit stopped at a privacy-safe fallback boundary.",
            "Retry once; if it repeats, restore the public source layout and rerun the audit.",
        ))
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True) if args.json else receipt["message"])
        return 1
    if args.json:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
    else:
        print(
            "Core module boundary audit: PASS "
            f"({receipt['coreSourceFileCount']} Core files, "
            f"{receipt['requiredPolicyCount']} required policies)"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
