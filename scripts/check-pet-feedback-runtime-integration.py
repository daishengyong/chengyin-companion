#!/usr/bin/env python3
"""Keep ephemeral pet feedback ownership focused and generation-safe."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  pet feedback runtime integration: {message}", file=sys.stderr)
    raise SystemExit(1)


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file() or path.is_symlink():
        fail(f"required regular file is missing: {relative}")
    return path.read_text(encoding="utf-8")


def require(relative: str, snippets: tuple[str, ...]) -> str:
    text = read(relative)
    for snippet in snippets:
        if snippet not in text:
            fail(f"{relative} lost required feedback ownership")
    return text


def main() -> int:
    coordinator = require(
        "Sources/CompanionApp/CompanionPetFeedbackRuntimeCoordinator.swift",
        (
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
            "guard duration.isFinite else",
            "guard delay.isFinite else",
            "let seconds = min(max(delay, 0), 60)",
        ),
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
        if token in coordinator:
            fail(f"feedback coordinator acquired forbidden capability: {token}")

    view_model = require(
        "Sources/CompanionApp/CompanionViewModel.swift",
        (
            "private let feedbackRuntime = CompanionPetFeedbackRuntimeCoordinator()",
            "get { feedbackRuntime.mood }",
            "get { feedbackRuntime.pose }",
            "var petEffect: PetEffect? { feedbackRuntime.effect }",
            "feedbackRuntime.objectWillChange.sink",
            "feedbackRuntime.presentEffect(",
            "feedbackRuntime.schedulePoseReset(",
            "feedbackRuntime.scheduleMoodReset(",
        ),
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
            fail("ephemeral pet reset ownership returned to CompanionViewModel")

    smoke = require(
        "scripts/pet-feedback-runtime-coordinator-smoke.swift",
        (
            "An older pose reset overwrote a newer interaction",
            "Ineligible mood reset changed an occupied interaction",
            "An older effect expiry cleared a newer effect",
            "Non-finite reset delay did not use the bounded immediate fallback",
            "Non-finite pose delay did not use the bounded immediate fallback",
            "Non-finite effect duration did not use the bounded immediate fallback",
        ),
    )
    if "Task.sleep" not in smoke:
        fail("behavior smoke no longer exercises overlapping asynchronous lifetimes")

    require(
        "scripts/run-pet-feedback-runtime-coordinator-smoke.sh",
        (
            "CompanionPetFeedbackRuntimeCoordinator.swift",
            "pet-feedback-runtime-coordinator-smoke.swift",
        ),
    )
    require(
        "scripts/doctor.sh",
        (
            "check-pet-feedback-runtime-integration.py",
            "run-pet-feedback-runtime-coordinator-smoke.sh",
        ),
    )
    require(
        ".github/workflows/ci.yml",
        (
            "check-pet-feedback-runtime-integration.py",
            "run-pet-feedback-runtime-coordinator-smoke.sh",
        ),
    )

    print(
        "PASS  pet feedback runtime integration: generation-safe mood, pose and "
        "effect lifetimes remain capability-free and delegated by App composition"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
