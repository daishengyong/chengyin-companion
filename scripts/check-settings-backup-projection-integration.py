#!/usr/bin/env python3
"""Keep portable settings export, restore repair and user receipts consistent."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  settings backup projection integration: {message}", file=sys.stderr)
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
            fail(f"{relative} lost required backup ownership: {snippet}")
    return text


def main() -> int:
    projection = require(
        "Sources/CompanionApp/CompanionSettingsBackupProjection.swift",
        (
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
        ),
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
        if token in projection:
            fail(f"settings backup projection acquired forbidden capability: {token}")

    view_model = require(
        "Sources/CompanionApp/CompanionViewModel.swift",
        (
            "CompanionSettingsBackupProjection.export(",
            "preferences: preferenceStore.load().snapshot",
            "CompanionSettingsBackupProjection.restore(",
            "currentLocale: Self.preferredContentLocale",
            "contentOperations.presentBackupRestoreCompletion(",
            "repairCount: repairs.count",
            "return plan.repairs",
        ),
    )
    for token in (
        "CompanionSettingsV1(",
        "settings.displayTarget.isValid",
        "settings.relationshipTone.allowsFlirtyReminders",
        "settings.relationshipTone.allowsRomanticGestures",
        "settings.reducedDynamicEffectsEnabled\n            ? .audioOnly",
    ):
        if token in view_model:
            fail(f"settings backup policy returned to App composition: {token}")

    require(
        "Sources/CompanionApp/CompanionBackupOperationsCoordinator.swift",
        (
            "func presentRestoreCompletion(",
            '"backup.operation.restoredWithAdjustments"',
            "installedPackCount,\n                repairCount",
        ),
    )
    require(
        "Sources/CompanionApp/CompanionContentOperationsCoordinator.swift",
        (
            "func presentBackupRestoreCompletion(",
            "backupOperations.presentRestoreCompletion(",
        ),
    )
    for locale in (
        "Sources/CompanionApp/Resources/en.lproj/Localizable.strings",
        "Sources/CompanionApp/Resources/zh-Hans.lproj/Localizable.strings",
    ):
        require(locale, ('"backup.operation.restoredWithAdjustments"',))

    require(
        "scripts/settings-backup-projection-smoke.swift",
        (
            "clean round-trip reported a repair",
            "invalid target did not fail safe",
            "low-dynamic restore did not force audio-only",
            "tone-disallowed flirt survived restore",
            "tone-disallowed pet name survived restore",
            "restore mutated its source settings",
            "repair receipt lost stable order",
            "already-compatible low-impact settings reported a false repair",
        ),
    )
    require(
        "scripts/run-settings-backup-projection-smoke.sh",
        (
            "-D COMPANION_STANDALONE_SMOKE",
            "CompanionSettingsBackupProjection.swift",
            "settings-backup-projection-smoke.swift",
        ),
    )
    for integration in ("scripts/Doctor.sh", ".github/workflows/ci.yml"):
        require(
            integration,
            (
                "check-settings-backup-projection-integration.py",
                "run-settings-backup-projection-smoke.sh",
            ),
        )

    print(
        "PASS  settings backup projection integration: export, explicit repair "
        "receipts, privacy retirement, safe fallback and UI completion copy remain aligned"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
