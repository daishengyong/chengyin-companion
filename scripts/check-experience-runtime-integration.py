#!/usr/bin/env python3
"""Keep shared-workday attention, lifetime and trusted replay in one runtime."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  experience-runtime integration: {message}", file=sys.stderr)
    raise SystemExit(1)


def source(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file() or path.is_symlink():
        fail(f"required regular source is missing: {relative}")
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        fail(f"required source is unreadable UTF-8: {relative}")


runtime = source(
    "Sources/CompanionApp/CompanionExperienceRuntimeCoordinator.swift"
)
view_model = source("Sources/CompanionApp/CompanionViewModel.swift")
play_controls = source("Sources/CompanionApp/CompanionPlayControls.swift")
models = source("Sources/CompanionApp/Models.swift")
smoke = source("scripts/experience-runtime-coordinator-smoke.swift")
doctor = source("scripts/doctor.sh")
ci = source(".github/workflows/ci.yml")
portable = source("scripts/run-portable-source-smoke.sh")

for claim in (
    "final class CompanionExperienceRuntimeCoordinator<",
    "private var director: CompanionExperienceDirector",
    "private var presentationTask: Task<Void, Never>?",
    "private var replayTask: Task<Void, Never>?",
    "private var handoffTask: Task<Void, Never>?",
    "CompanionExperiencePresentationToken",
    "case acceptedTrustedOverflow",
    "case coalescedTrustedTerminal",
    "func scheduleFinish(",
    "func schedulePendingDelivery(",
    "func scheduleHandoff(",
    "func noteUserInitiated(",
):
    if claim not in runtime:
        fail(f"focused runtime lost {claim}")

for forbidden in (
    "import AppKit",
    "UserDefaults.",
    "VoicePackPlayer",
    "NSHapticFeedbackManager",
    "var taskRef",
    "let taskRef",
    "var prompt",
    "let prompt",
    "var sourceCode",
    "let sourceCode",
    "var absolutePath",
    "let absolutePath",
):
    if forbidden in runtime:
        fail(f"runtime gained presentation, persistence or private content: {forbidden}")

for claim in (
    "CompanionExperienceRuntimeCoordinator<CompanionEventKind>()",
    "experienceRuntime.objectWillChange.sink",
    "experienceRuntime.decide(",
    "experienceRuntime.enqueue(",
    "experienceRuntime.beginPresentation()",
    "experienceRuntime.scheduleFinish(",
    "experienceRuntime.schedulePendingDelivery(",
    "experienceRuntime.scheduleHandoff(",
    "experienceRuntime.noteUserInitiated(",
    "noteUserInitiatedExperience(at: date)",
):
    if claim not in view_model:
        fail(f"view model binding lost {claim}")

for obsolete in (
    "eventTask",
    "pendingPriorityEvents",
    "PendingCompanionEvent",
    "private var experienceDirector",
):
    if obsolete in view_model:
        fail(f"parallel experience ownership returned to view model: {obsolete}")

if view_model.count("noteUserInitiatedExperience(at: date)") < 2:
    fail("single and double pet taps no longer register direct-play attention")
if "noteUserInitiatedExperience()" not in view_model:
    fail("long-press and drag play no longer register direct-play attention")
if "viewModel.noteUserInitiatedExperience()" not in play_controls:
    fail("magic-wand selections no longer register direct-play attention")

if "CompanionEventKind: String, Codable, CaseIterable, Hashable, Sendable" not in models:
    fail("event keys are not content-free Hashable/Sendable queue tokens")

for behavior in (
    "trusted overflow",
    "post-user-interaction attention grace",
    "generation-safe finish",
    "stale-handoff cancellation",
    "readiness replay",
):
    if behavior not in smoke:
        fail(f"runtime behavior smoke lost {behavior}")

for surface_name, text in (
    ("doctor", doctor),
    ("CI", ci),
    ("portable source smoke", portable),
):
    if "run-experience-runtime-coordinator-smoke.sh" not in text:
        fail(f"runtime behavior smoke is not wired into {surface_name}")
    if "check-experience-runtime-integration.py" not in text:
        fail(f"runtime integration guard is not wired into {surface_name}")

print(
    "PASS  experience-runtime integration: one attention director, generation-safe "
    "presentation, post-user-interaction grace, trusted terminal retention and "
    "stale-fallback cancellation"
)
