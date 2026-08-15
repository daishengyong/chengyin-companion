#!/usr/bin/env python3
"""Keep local preference migration, repair and privacy cleanup focused."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  preference store integration: {message}", file=sys.stderr)
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
            fail(f"{relative} lost required preference ownership: {snippet}")
    return text


def main() -> int:
    store = require(
        "Sources/CompanionApp/CompanionPreferenceStore.swift",
        (
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
            '"chengyin.ui.messages"',
            '"chengyin.codex.thread-id"',
            "guard target.isValid else",
            "range: 0...5",
            "func savePlaybackMode(",
            "func saveLocalContentPacksEnabled(",
            "func saveCatchGameBestScore(",
            "func saveHideGameBestScore(",
        ),
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
    ):
        if token in store:
            fail(f"preference store acquired forbidden capability: {token}")

    view_model = require(
        "Sources/CompanionApp/CompanionViewModel.swift",
        (
            "private let preferenceStore = CompanionPreferenceStore()",
            "let savedPreferences = preferenceStore.load().snapshot",
            "preferenceStore.savePlaybackMode(playbackMode)",
            "preferenceStore.saveDisplayTarget(displayTarget)",
            "preferenceStore.saveLocalContentPacksEnabled(localContentPacksEnabled)",
            "preferenceStore.saveCatchGameBestScore(catchGameBestScore)",
            "preferenceStore.saveHideGameBestScore(hideGameBestScore)",
        ),
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
            fail(f"preference persistence returned to App composition: {token}")

    require(
        "scripts/preference-store-smoke.swift",
        (
            "Clean playback default changed",
            "Legacy accidental audio-only was not migrated",
            "Future contract was silently downgraded",
            "Corrupt boolean did not use safe default",
            "Unsafe display target was retained",
            "Privacy cleanup receipt was incorrect",
            "Repairs were not stable across restart",
            "Score writes were not bounded",
        ),
    )
    require(
        "scripts/run-preference-store-smoke.sh",
        (
            "CompanionPreferenceStore.swift",
            "preference-store-smoke.swift",
        ),
    )
    for integration in (
        "scripts/Doctor.sh",
        ".github/workflows/ci.yml",
    ):
        require(
            integration,
            (
                "check-preference-store-integration.py",
                "run-preference-store-smoke.sh",
            ),
        )

    print(
        "PASS  preference store integration: typed defaults, one-way migration, "
        "malformed repair and retired privacy-key cleanup remain focused"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
