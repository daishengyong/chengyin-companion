#!/usr/bin/env python3
"""Keep the privacy-minimal shared-workday recovery path coherent."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"FAIL  workday integration: {message}", file=sys.stderr)
        raise SystemExit(1)


def source(relative: str) -> str:
    path = ROOT / relative
    require(path.is_file() and not path.is_symlink(), f"missing or unsafe {relative}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    state = source("Sources/CompanionContracts/CompanionWorkdayState.swift")
    director = source("Sources/CompanionContracts/CompanionWorkDirector.swift")
    experience = source(
        "Sources/CompanionContracts/CompanionWorkdayExperiencePolicy.swift"
    )
    signal_trust = source(
        "Sources/CompanionContracts/CompanionWorkdaySignalTrustPolicy.swift"
    )
    completion_policy = source(
        "Sources/CompanionContracts/CompanionTaskCompletionPolicy.swift"
    )
    adapter = source("Sources/CompanionApp/CompanionWorkdayAdapter.swift")
    runtime = source(
        "Sources/CompanionApp/CompanionWorkdayRuntimeCoordinator.swift"
    )
    presentation = source(
        "Sources/CompanionApp/CompanionWorkdayPresentation.swift"
    )
    application_projection = source(
        "Sources/CompanionApp/CompanionWorkdayApplicationProjection.swift"
    )
    completion_presentation = source(
        "Sources/CompanionApp/CompanionTaskCompletionPresentation.swift"
    )
    event_presentation = source(
        "Sources/CompanionApp/CompanionEventPresentation.swift"
    )
    trigger_routing = source(
        "Sources/CompanionApp/CompanionEventTriggerRouting.swift"
    )
    content_pack = source("Sources/CompanionApp/ContentPack.swift")
    trigger_contract = source(
        "Sources/CompanionApp/ContentPackTriggerContract.swift"
    )
    pack_schema = source("Schemas/content-pack-v2.schema.json")
    experience_author = source("scripts/apply-content-pack-experience.py")
    ingress = source("Sources/CompanionApp/CompanionEventIngress.swift")
    services = source("Sources/CompanionApp/CompanionEventWatcher.swift")
    view_model = source("Sources/CompanionApp/CompanionViewModel.swift")
    diagnostics = source("Sources/CompanionApp/CompanionDiagnostics.swift")
    errors = source("Sources/CompanionApp/CompanionErrorPresentation.swift")
    registry = source("Schemas/error-codes-v1.json")
    tests = source("Tests/CompanionContractsTests/main.swift")
    doctor = source("scripts/doctor.sh")
    ci = source(".github/workflows/ci.yml")
    smoke = source("scripts/workday-runtime-coordinator-smoke.swift")
    smoke_runner = source("scripts/run-workday-runtime-coordinator-smoke.sh")

    for claim in (
        "public struct CompanionWorkdayStateV1",
        "public enum CompanionWorkdayStateRecoverySource",
        "public struct CompanionWorkdayStateLoadResult",
        "loadWithRecovery(",
        "case backup",
        "case safeDefault",
        "public func reset",
    ):
        require(claim in state, f"Core workday recovery contract lost {claim}")
    for forbidden_field in (
        "taskTitle",
        "prompt",
        "sourceCode",
        "absolutePath",
        "repositoryPath",
    ):
        require(
            f"var {forbidden_field}" not in state
            and f"let {forbidden_field}" not in state,
            f"workday persistence gained private field {forbidden_field}",
        )
    for forbidden_dependency in ("URLSession", "StoreKit", "AVPlayer", "NSWorkspace"):
        require(
            forbidden_dependency not in state
            and forbidden_dependency not in director
            and forbidden_dependency not in experience
            and forbidden_dependency not in signal_trust
            and forbidden_dependency not in completion_policy,
            f"Core workday path gained side effect {forbidden_dependency}",
        )

    for claim in (
        "public enum CompanionWorkdayStatusIntent",
        "public enum CompanionWorkdayContentCue",
        "public struct CompanionWorkdayPresentationContext",
        "public struct CompanionWorkdayPresentationPlan",
        "public enum CompanionWorkdayExperiencePolicy",
        "allowsPassivePresenceUpdate",
        "contentCue:",
    ):
        require(claim in experience, f"Core workday experience policy lost {claim}")
    for claim in (
        "public enum CompanionWorkdaySignalOrigin",
        "public enum CompanionWorkdaySignalSourcePolicy",
        "public enum CompanionWorkdaySignalTrustPolicy",
        '("codex-skill", "terminal-events-v1")',
        '("codex-app-server", "turn-events-v1")',
        "case (.taskCompleted, .success, .companionTerminalEmitter)",
        "case (.taskCompleted, _, _)",
    ):
        require(claim in signal_trust, f"Core workday signal trust policy lost {claim}")
    require(
        "effectiveWorkdayEventType" in ingress
        and "CompanionWorkdaySignalSourcePolicy.origin(" in ingress
        and "CompanionWorkdaySignalTrustPolicy.effectiveType(" in ingress,
        "event extraction bypasses the shared completion-trust policy",
    )
    for claim in (
        "primeProtocolInbox()",
        "private var primedSignals: [CodexTaskSignal] = []",
        "private var protocolInboxPrimed = false",
        "startedAt: .distantPast",
        "if signal.occurredAt >= startedAt",
    ):
        require(claim in services, f"restart-safe event baselining lost {claim}")
    require(
        "CompanionWorkdayPresentationCopy" in presentation
        and "cueEffect(" in presentation
        and "appVisualState" in presentation
        and "appMood" in presentation,
        "localized workday presentation mapping returned to the view model",
    )
    for claim in (
        "enum CompanionWorkdayApplicationProjection",
        "struct CompanionWorkdayApplicationPlan",
        "enum CompanionWorkdayApplicationEvent",
        "relationship: isCompletion",
        "visual != .completed || allowsCompleted",
        'momentID: "task.completed"',
    ):
        require(
            claim in application_projection,
            f"completion-safe App projection lost {claim}",
        )
    for forbidden_detail in (
        "URLSession",
        "UserDefaults",
        "VoicePackPlayer",
        "NSWindow",
        "Task {",
        "FileManager",
    ):
        require(
            forbidden_detail not in application_projection,
            f"workday App projection gained side effect {forbidden_detail}",
        )
    for claim in (
        "public enum CompanionCompletionReplyGesture",
        "public enum CompanionTaskCompletionRewardBeat",
        "public enum CompanionTaskCompletionCopyIntent",
        "public struct CompanionTaskCompletionCelebrationPlan",
        "public struct CompanionCompletionReplyPlan",
        "public enum CompanionTaskCompletionPolicy",
        "allowsRomanticGestures: Bool",
        "variation: UInt64",
        'relationshipKey: "reply.\\(gesture.rawValue)"',
    ):
        require(
            claim in completion_policy,
            f"Core task-completion interaction policy lost {claim}",
        )
    for forbidden_detail in (
        "taskTitle",
        "prompt:",
        "sourceCode",
        "repositoryPath",
        "UserDefaults",
        "VoicePackPlayer",
        "NSWindow",
        "Task {",
    ):
        require(
            forbidden_detail not in completion_policy,
            f"Core task-completion policy gained private or side-effect detail {forbidden_detail}",
        )
    for claim in (
        "struct CompanionTaskCompletionPresentation",
        "static func celebration(",
        "static func reply(",
        "CompanionTaskCompletionPolicy.celebration(",
        "CompanionTaskCompletionPolicy.reply(",
        'key: "completion.line.recovered"',
        'key: "completion.line.signature"',
    ):
        require(
            claim in completion_presentation,
            f"localized task-completion projection lost {claim}",
        )
    for forbidden_detail in (
        "import AppKit",
        "import SwiftUI",
        "UserDefaults",
        "VoicePackPlayer",
        "NSHapticFeedbackManager",
        "NSWindow",
        "Task {",
    ):
        require(
            forbidden_detail not in completion_presentation,
            f"task-completion projection gained side effect {forbidden_detail}",
        )
    require(
        "enum CompanionEventPresentation" in event_presentation
        and "enum CompanionEventTriggerRouting" in trigger_routing
        and '["responseReady", "manual:event.\\(event.rawValue)"]'
        in trigger_routing,
        "event copy or canonical response-ready trigger fallback returned to the view model",
    )
    workday_triggers = (
        "taskStarted",
        "taskLongRunning",
        "taskCancelled",
        "responseReady",
    )
    for trigger in workday_triggers:
        require(
            trigger in trigger_contract
            and trigger in pack_schema
            and trigger in experience_author,
            f"declarative workday trigger drifted across validator/schema/author: {trigger}",
        )
    require(
        'workdayMinimumAppVersion = "0.19.42"' in trigger_contract
        and "ContentPackTriggerContract.validateCompatibility(" in content_pack
        and "PACK_VALIDATION_WORKDAY_TRIGGER_REQUIRES_APP_VERSION" in registry,
        "workday trigger compatibility gate or stable failure code is missing",
    )

    for claim in (
        "CompanionWorkdayStateStore",
        "CompanionWorkDirector",
        "result.recoverySource",
        "CompanionWorkdayMutationReceipt",
        "persistenceError: persistDirectorState()",
        "WORKDAY_PERSISTENCE_FAILED",
        "WORKDAY_RESET_FAILED",
    ):
        require(claim in adapter, f"App workday adapter lost {claim}")
    for claim in (
        "final class CompanionWorkdayRuntimeCoordinator: ObservableObject",
        "@Published private(set) var state",
        "private var pollingTask: Task<Void, Never>?",
        "private var replyTask: Task<Void, Never>?",
        "CompanionWorkdayExperiencePolicy.plan(",
        "isCurrentPollingGeneration",
        "isCurrentReplyGeneration",
        "refreshEventBridgeReadiness",
        "repairEventBridge",
    ):
        require(claim in runtime, f"workday runtime lost {claim}")
    for forbidden_detail in (
        "taskTitle",
        "sourceCode",
        "repositoryPath",
        "AVPlayer",
        "NSWindow",
        "VoicePackPlayer",
    ):
        require(
            forbidden_detail not in runtime,
            f"workday runtime gained private or presentation detail {forbidden_detail}",
        )
    require(
        "workdayRuntime.consume(" in view_model
        and "applyWorkdayPresentation(" in view_model
        and "CompanionWorkdayApplicationProjection.project(" in view_model,
        "view model does not consume one coherent runtime receipt",
    )
    for raw_projection in (
        "presentation.visual",
        "presentation.relationshipReward",
        "switch presentation.event",
    ):
        require(
            raw_projection not in view_model,
            f"raw workday presentation mapping returned to the view model: {raw_projection}",
        )
    for obsolete in (
        "workdayStateStore",
        "private var workDirector",
        "persistWorkdaySnapshot",
        "signal.type == .taskCompleted",
        "private let completionWatcher",
        "private let workdayAdapter",
        "private var completionTask",
        "private var completionReplyTask",
        "private var completionReplyDeadline",
        "CompanionWorkdayExperiencePolicy.plan(",
        "private enum CompletionReplyStyle",
        "private func completionReplyAction(",
        "private func completionAction(",
        "private func completionLine(",
        '"reply.long-press"',
    ):
        require(obsolete not in view_model, f"raw workday orchestration returned: {obsolete}")
    for claim in (
        "CompanionTaskCompletionPresentation.celebration(",
        "CompanionTaskCompletionPolicy.reply(",
        "private func applyCompletionReply(",
    ):
        require(claim in view_model, f"task-completion handoff lost {claim}")

    for claim in (
        "False or duplicate completion reached workday state",
        "Response-ready was reinterpreted as a completion side effect",
        "Malformed non-terminal input escaped the completion-only projection gate",
        "Stopped poller delivered a signal",
        "An older reply timer closed the newer reply window",
        "Closed reply window emitted a stale callback",
        "Explicit workday reset did not clear the coordinated snapshot",
    ):
        require(claim in smoke, f"workday runtime smoke lost {claim}")
    require(
        "CompanionWorkdayRuntimeCoordinator.swift" in smoke_runner
        and "CompanionWorkdayApplicationProjection.swift" in smoke_runner
        and "workday-runtime-coordinator-smoke.swift" in smoke_runner,
        "workday runtime behavior runner lost its focused sources",
    )

    require(
        "workdayRecoverySource" in diagnostics
        and "Workday recovery:" in diagnostics,
        "privacy-safe workday recovery identity is absent from diagnostics",
    )
    for private_detail in ("taskRef", "eventID", "lastFailureAt"):
        require(private_detail not in diagnostics, f"diagnostics expose {private_detail}")
    require(
        "CompanionWorkdayAdapterError" in errors
        and "workdayDescriptor" in errors,
        "workday failures lost privacy-safe user presentation",
    )
    for code in ("WORKDAY_PERSISTENCE_FAILED", "WORKDAY_RESET_FAILED"):
        require(code in adapter and code in registry, f"stable error registry lost {code}")
    for test_name in (
        "Workday state is privacy-minimal and round-trips",
        "Work director creates a continuous recovery arc",
        "Workday trust policy rejects false completion claims",
        "Workday presentation policy preserves occupied attention",
        "Task completion celebration is tiered and romance-capped",
        "Task completion replies are bounded and privacy-minimal",
        "Workday state rolls over without carrying yesterday's score",
        "Workday store recovers the last valid snapshot",
        "Explicit workday forgetting clears rollback data",
    ):
        require(test_name in tests, f"contract matrix lost {test_name}")
    require(
        "recovered.recoverySource == .backup" in tests
        and "recovered.recoverySource == .safeDefault" in tests,
        "contract matrix does not distinguish backup and safe-default recovery",
    )
    require(
        "check-workday-integration.py" in doctor
        and "check-workday-integration.py" in ci
        and "run-workday-runtime-coordinator-smoke.sh" in doctor
        and "run-workday-runtime-coordinator-smoke.sh" in ci,
        "Doctor or CI does not execute the workday integration guard",
    )

    print(
        "PASS  workday integration: explicit recovery, shared completion trust, "
        "generation-safe reply lifetime, cancellable polling, attention-safe "
        "declarative version-gated cues, completion-safe App projection, "
        "tiered completion replies, stable failures, "
        "privacy-safe diagnostics"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
