#!/usr/bin/env python3
"""Keep the shared care/work lifecycle narrow, cancellable and coherent."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"FAIL  shared-day integration: {message}", file=sys.stderr)
        raise SystemExit(1)


def source(relative: str) -> str:
    path = ROOT / relative
    require(path.is_file() and not path.is_symlink(), f"missing or unsafe {relative}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    runtime = source(
        "Sources/CompanionApp/CompanionSharedDayRuntimeCoordinator.swift"
    )
    view_model = source("Sources/CompanionApp/CompanionViewModel.swift")
    smoke = source("scripts/shared-day-runtime-coordinator-smoke.swift")
    runner = source("scripts/run-shared-day-runtime-coordinator-smoke.sh")
    doctor = source("scripts/doctor.sh")
    ci = source(".github/workflows/ci.yml")

    for claim in (
        "final class CompanionSharedDayRuntimeCoordinator: ObservableObject",
        "let workday: CompanionWorkdayRuntimeCoordinator",
        "let lifestyle: CompanionLifestyleRuntimeCoordinator",
        "private var careTask: Task<Void, Never>?",
        "private var careGeneration: UInt64 = 0",
        "func evaluateCare(",
        "func start(",
        "func stop()",
        "isCurrentCareGeneration",
    ):
        require(claim in runtime, f"shared-day runtime lost {claim}")

    for forbidden in (
        "AVPlayer",
        "NSWindow",
        "VoicePackPlayer",
        "taskTitle",
        "prompt",
        "sourceCode",
        "absolutePath",
        "relationshipTone",
    ):
        require(forbidden not in runtime, f"shared-day runtime gained {forbidden}")

    require(
        "private let sharedDayRuntime: CompanionSharedDayRuntimeCoordinator"
        in view_model,
        "view model does not own one shared-day composition root",
    )
    require(
        "startSharedDayRuntime()" in view_model
        and "sharedDayRuntime.start(" in view_model
        and "sharedDayRuntime.evaluateCare(" in view_model,
        "view model bypasses the shared-day lifecycle",
    )
    for obsolete in (
        "private var reminderTask",
        "private func startReminderLoop",
        "private func startCompletionWatcher",
        "workdayRuntime.startPolling(",
        "lifestyleRuntime.evaluate(",
        "workdayRuntime.refreshDay(",
    ):
        require(obsolete not in view_model, f"split lifecycle returned: {obsolete}")

    for behavior in (
        "A replaced care generation emitted a stale callback",
        "Shared workday clock did not deliver a trusted signal",
        "Stopped shared day emitted a care callback",
        "Stopped shared day emitted a work callback",
    ):
        require(behavior in smoke, f"shared-day smoke lost {behavior}")
    require(
        "CompanionSharedDayRuntimeCoordinator.swift" in runner
        and "shared-day-runtime-coordinator-smoke.swift" in runner,
        "shared-day runner lost focused sources",
    )
    require(
        "check-shared-day-integration.py" in doctor
        and "run-shared-day-runtime-coordinator-smoke.sh" in doctor
        and "check-shared-day-integration.py" in ci
        and "run-shared-day-runtime-coordinator-smoke.sh" in ci,
        "Doctor or CI does not execute both shared-day gates",
    )

    print(
        "PASS  shared-day integration: one bounded care/work lifecycle, "
        "generation-safe timing, semantic receipts and privacy-minimal facts"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
