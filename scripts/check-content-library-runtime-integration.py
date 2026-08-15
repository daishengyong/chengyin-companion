#!/usr/bin/env python3
"""Keep local content-library runtime state focused and stale-safe."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  content library runtime integration: {message}", file=sys.stderr)
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
            fail(f"{relative} lost required content-library runtime ownership")
    return text


def main() -> int:
    coordinator = require(
        "Sources/CompanionApp/CompanionContentLibraryRuntimeCoordinator.swift",
        (
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
            "ContentPackRuntimeCatalog(",
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
        "NSPasteboard",
    ):
        if token in coordinator:
            fail(f"content-library runtime acquired forbidden capability: {token}")

    view_model = require(
        "Sources/CompanionApp/CompanionViewModel.swift",
        (
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
        ),
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
            fail("content-library runtime ownership returned to CompanionViewModel")

    smoke = require(
        "scripts/content-library-runtime-coordinator-smoke.swift",
        (
            "Duplicate playback validation was accepted",
            "Stale playback success overwrote a newer retry",
            "Cancelled recovery overwrote a newer inventory",
            "Safe mode retained runtime media",
            "Recovery failure callback count was not bounded",
        ),
    )
    if "Task.yield" not in smoke:
        fail("behavior smoke no longer exercises overlapping recovery callbacks")
    require(
        "scripts/run-content-library-runtime-coordinator-smoke.sh",
        (
            "CompanionContentLibraryRuntimeCoordinator.swift",
            "content-library-runtime-coordinator-smoke.swift",
        ),
    )
    require(
        "scripts/doctor.sh",
        (
            "check-content-library-runtime-integration.py",
            "run-content-library-runtime-coordinator-smoke.sh",
        ),
    )
    require(
        ".github/workflows/ci.yml",
        (
            "check-content-library-runtime-integration.py",
            "run-content-library-runtime-coordinator-smoke.sh",
        ),
    )

    print(
        "PASS  content library runtime integration: immutable inventory projection, "
        "safe-mode fallback and generation-safe recovery/playback validation remain focused"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
