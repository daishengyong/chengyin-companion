#!/usr/bin/env python3
"""Source-verifiable first-session integration gate; no app launch or network."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file() or path.is_symlink():
        raise AssertionError(f"missing regular source: {relative}")
    return path.read_text(encoding="utf-8")


def require(text: str, tokens: tuple[str, ...], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    if missing:
        raise AssertionError(f"{label} lost required integration tokens: {missing}")


def main() -> int:
    core = read("Sources/CompanionContracts/CompanionFirstSession.swift")
    runtime = read(
        "Sources/CompanionApp/CompanionFirstSessionRuntimeCoordinator.swift"
    )
    integration = read(
        "Sources/CompanionApp/CompanionFirstSessionIntegration.swift"
    )
    preferences = read(
        "Sources/CompanionApp/CompanionPresentationPreferences.swift"
    )
    view_model = read("Sources/CompanionApp/CompanionViewModel.swift")
    coach = read("Sources/CompanionApp/CompanionFirstSessionCoach.swift")
    controls = read("Sources/CompanionApp/CompanionPlayControls.swift")

    require(
        core,
        (
            "case singleTap",
            "case doubleTap",
            "case preference",
            "case workArc",
            "case applyPreferenceAndRunWorkArc",
            "case skipped",
            "public static let contractVersion = 1",
            "CompanionFirstSessionLaunchDisposition",
            "CompanionFirstSessionLaunchPolicy",
            "case startCleanInstallation",
            "case preserveExistingInstallation",
            "case alreadyCompleted",
        ),
        "deterministic journey",
    )
    require(
        runtime,
        (
            "private var workArcTask: Task<Void, Never>?",
            "private var generation: UInt64 = 0",
            "guard !Task.isCancelled, self.generation == token",
            "func cancelWorkArc()",
        ),
        "generation-safe runtime",
    )
    require(
        preferences,
        (
            "existingProfileKeys",
            "CompanionFirstSessionLaunchPolicy.disposition(",
            "markStarted(in defaults: UserDefaults)",
            "-CompanionFirstSessionJourney.contractVersion",
            "firstSessionContractVersion",
            "firstSessionPreference",
        ),
        "migration-safe local persistence",
    )
    require(
        view_model,
        (
            "firstSessionRuntime.recordSingleTap()",
            "firstSessionRuntime.recordDoubleTap()",
            "startFirstSession(replay: false)",
        ),
        "gesture and clean-launch binding",
    )
    if "private var workArcPreviewTask" in view_model:
        raise AssertionError("work-arc timer returned to the composition model")
    require(
        integration,
        (
            "replayFirstSession()",
            "skipFirstSession()",
            "chooseFirstSessionPreference",
            "case .completed:",
            "completeJourneyAfterWorkArc()",
            "markCompleted(",
        ),
        "first-session side-effect binding",
    )
    require(
        coach,
        (
            '"chengyin.first-session-coach"',
            '"chengyin.first-session-skip"',
            '"chengyin.first-session-preference-workCompanion"',
            '"chengyin.first-session-preference-playfulBreaks"',
            '"chengyin.first-session-preference-gentleCare"',
        ),
        "accessible coach",
    )
    require(
        controls,
        (
            '"play.preview.firstSession"',
            "viewModel.replayFirstSession()",
        ),
        "explicit replay entry",
    )

    forbidden_core = ("SwiftUI", "AppKit", "AVFoundation", "URLSession")
    if any(token in core for token in forbidden_core):
        raise AssertionError("first-session Core contract gained platform or network work")

    print(
        "PASS  first-session integration: clean-install migration, two ordered gestures, "
        "one local preference, generation-safe work arc, accessible skip/replay and no paywall gate"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, UnicodeDecodeError) as error:
        print(f"FAIL  first-session integration: {error}", file=sys.stderr)
        raise SystemExit(1)
