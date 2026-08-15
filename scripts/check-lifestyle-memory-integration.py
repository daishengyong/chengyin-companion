#!/usr/bin/env python3
"""Keep privacy-minimal lifestyle memory recovery wired across Core and App."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"FAIL  lifestyle-memory integration: {message}", file=sys.stderr)
        raise SystemExit(1)


def source(relative: str) -> str:
    path = ROOT / relative
    require(path.is_file() and not path.is_symlink(), f"missing or unsafe {relative}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    core = source("Sources/CompanionContracts/CompanionLifestyleMemory.swift")
    adapter = source("Sources/CompanionApp/CompanionLifestyleMemoryAdapter.swift")
    runtime = source("Sources/CompanionApp/CompanionLifestyleRuntimeCoordinator.swift")
    event_projection = source(
        "Sources/CompanionApp/CompanionLifestyleEventProjection.swift"
    )
    presentation = source("Sources/CompanionApp/CompanionLifestylePresentation.swift")
    view_model = source("Sources/CompanionApp/CompanionViewModel.swift")
    diagnostics = source("Sources/CompanionApp/CompanionDiagnostics.swift")
    errors = source("Sources/CompanionApp/CompanionErrorPresentation.swift")
    registry = source("Schemas/error-codes-v1.json")
    tests = source("Tests/CompanionContractsTests/main.swift")
    runtime_smoke = source("scripts/lifestyle-runtime-coordinator-smoke.swift")
    policy_smokes = source("scripts/run-core-policy-smokes.sh")
    doctor = source("scripts/doctor.sh")
    ci = source(".github/workflows/ci.yml")

    for claim in (
        "public struct CompanionLifestyleMemoryV1",
        "public final class CompanionLifestyleMemoryStore",
        "public enum CompanionLifestyleMemoryRecoverySource",
        "maximumPayloadBytes = 64 * 1024",
        "case backup",
        "case legacyProjection",
        "case safeDefault",
        "public func reset",
        "legacyProjection",
    ):
        require(claim in core, f"Core recovery contract lost {claim}")
    for forbidden_field in ("taskTitle", "prompt", "sourceCode", "absolutePath"):
        require(
            f"var {forbidden_field}" not in core
            and f"let {forbidden_field}" not in core,
            f"privacy boundary gained field {forbidden_field}",
        )
    for forbidden_dependency in ("URLSession", "NSMicrophoneUsageDescription", "StoreKit"):
        require(
            forbidden_dependency not in core,
            f"privacy boundary gained {forbidden_dependency}",
        )

    require(
        "CompanionLifestyleMemoryStore" in adapter
        and "result.recoverySource" in adapter
        and "CARE_MEMORY_PERSISTENCE_FAILED" in adapter
        and "CARE_MEMORY_RESET_FAILED" in adapter,
        "App adapter lost store, recovery receipt, or stable failures",
    )
    require(
        "final class CompanionLifestyleRuntimeCoordinator" in runtime
        and "private let memoryAdapter: CompanionLifestyleMemoryAdapter" in runtime
        and "CompanionLifestyleScheduler(" in runtime
        and "func recordDelivered" in runtime
        and "func reset(at now: Date)" in runtime,
        "runtime coordinator lost memory ownership, scheduling, or lifecycle",
    )
    require(
        "sharedDayRuntime" in view_model
        and "carePausedUntil: Date? { lifestyleRuntime.pausedUntil }" in view_model
        and "sharedDayRuntime.evaluateCare(" in view_model
        and "CompanionLifestylePresentation.status(" in view_model,
        "view model is not binding the shared-day receipt and care presentation outcome",
    )
    require(
        "enum CompanionLifestyleEventProjection" in event_projection
        and "static func deliveryPlan(" in event_projection
        and "CompanionLifestyleEventProjection.deliveryPlan(" in view_model
        and "deliveryPlan(" not in presentation,
        "semantic care-event projection is not isolated from localized status copy",
    )
    for obsolete in (
        "lifestyleMemoryAdapter",
        "CompanionLifestyleScheduler(",
        "private var lifestyleSessionStartedAt",
        "private var lifestyleWasUserRecentlyActive",
        "private var lifestyleReturnedAt",
        "private var lifestyleActivityAnchor",
        "private var lifestyleLastReminder",
        "private var lifestyleLastReminderByKind",
        "private var lifestyleDailyCounts",
        "private var lifestyleDailyDay",
        "private var lifestyleRandomSeed",
        "restoreLifestyleSchedule",
    ):
        require(obsolete not in view_model, f"raw care state returned to the view model: {obsolete}")
    require(
        "enum CompanionLifestylePresentation" in presentation
        and "static func status(" in presentation
        and "static func delivered(" in presentation,
        "localized care status projection is not isolated",
    )
    require(
        "careMemoryRecoverySource" in diagnostics
        and "Care memory recovery:" in diagnostics,
        "privacy-safe recovery identity is absent from diagnostics",
    )
    for private_detail in ("lastReminder", "dailyCounts", "pausedUntil"):
        require(private_detail not in diagnostics, f"diagnostics expose {private_detail}")
    require(
        "CompanionLifestyleMemoryAdapterError" in errors
        and "case .persistenceFailed" in errors
        and "case .resetFailed" in errors,
        "care-memory failures lost privacy-safe user presentation",
    )
    for code in ("CARE_MEMORY_PERSISTENCE_FAILED", "CARE_MEMORY_RESET_FAILED"):
        require(code in adapter and code in registry, f"stable error registry lost {code}")
    for test_name in (
        "Care-rhythm memory is bounded and privacy-minimal",
        "Care-rhythm recovery rejects stale and future state",
        "Care-rhythm store migrates and projects legacy state",
        "Care-rhythm store recovers the last valid snapshot",
        "Explicit care-memory deletion clears rollback history",
        "Care-rhythm codec rejects unsupported and invalid state",
    ):
        require(test_name in tests, f"contract matrix lost {test_name}")
    for behavior in (
        "disabled state drifted",
        "pause deadline was not preserved",
        "away state drifted",
        "return cooldown deadline drifted",
        "quiet-hours boundary drifted",
        "delivered reminder was not recorded",
        "reset retained reminder",
    ):
        require(behavior in runtime_smoke, f"runtime behavior smoke lost {behavior}")
    require(
        "lifestyle-runtime-coordinator-smoke.swift" in policy_smokes,
        "Core policy smokes do not execute the App runtime coordinator boundary",
    )
    require(
        "check-lifestyle-memory-integration.py" in doctor
        and "check-lifestyle-memory-integration.py" in ci,
        "doctor or CI does not execute this integration guard",
    )

    print(
        "PASS  lifestyle-memory integration: schema v1, legacy migration, "
        "backup recovery, runtime coordination, deletion, privacy-safe diagnostics"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
