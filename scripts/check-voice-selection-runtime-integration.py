#!/usr/bin/env python3
"""Keep bounded voice selection separate from playback and App composition."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  voice selection runtime integration: {message}", file=sys.stderr)
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
            fail(f"{relative} lost required voice-selection ownership: {snippet}")
    return text


def main() -> int:
    runtime = require(
        "Sources/CompanionApp/CompanionVoiceSelectionRuntimeCoordinator.swift",
        (
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
            "return .cooldown",
            "return .unavailable",
        ),
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
        if token in runtime:
            fail(f"voice selection runtime acquired forbidden capability: {token}")

    view_model = require(
        "Sources/CompanionApp/CompanionViewModel.swift",
        (
            "private let voiceSelection = CompanionVoiceSelectionRuntimeCoordinator(",
            "voiceFileNames: voiceSelection.audioFileNames",
            "voiceSelection.selectAction(",
            "voiceSelection.selectEvent(",
            "voiceSelection.selectInteraction(",
            "case .cooldown:",
            "case .unavailable:",
            "case let .line(line):",
        ),
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
            fail(f"voice-selection state returned to App composition: {token}")

    require(
        "scripts/voice-selection-runtime-smoke.swift",
        (
            "general history repeated before the public pool was exhausted",
            "addressed line bypassed the opt-in gate",
            "preferred line lost exact-ID priority",
            "action history repeated before exhaustion",
            "interaction cooldown was not enforced",
            "explicit cooldown bypass did not select a line",
            "missing interaction event did not return unavailable",
            "general history leaked into interaction history",
        ),
    )
    require(
        "scripts/run-voice-selection-runtime-smoke.sh",
        (
            "CompanionVoiceSelectionRuntimeCoordinator.swift",
            "voice-selection-runtime-smoke.swift",
        ),
    )
    for integration in ("scripts/Doctor.sh", ".github/workflows/ci.yml"):
        require(
            integration,
            (
                "check-voice-selection-runtime-integration.py",
                "run-voice-selection-runtime-smoke.sh",
            ),
        )

    print(
        "PASS  voice selection runtime integration: bounded general/interaction "
        "history, preferred-ID filtering and cooldown remain playback-free"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
