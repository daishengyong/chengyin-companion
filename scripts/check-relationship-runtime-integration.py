#!/usr/bin/env python3
"""Keep relationship memory, feedback and selection outside app composition."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  relationship-runtime integration: {message}", file=sys.stderr)
    raise SystemExit(1)


def source(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file() or path.is_symlink():
        fail(f"required regular file is missing: {relative}")
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        fail(f"required UTF-8 source is unreadable: {relative}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def main() -> int:
    coordinator = source(
        "Sources/CompanionApp/CompanionRelationshipRuntimeCoordinator.swift"
    )
    selection_adapter = source(
        "Sources/CompanionApp/CompanionRelationshipContentSelection.swift"
    )
    view_model = source("Sources/CompanionApp/CompanionViewModel.swift")
    architecture = source("docs/CONTRIBUTOR-ARCHITECTURE.md")
    boundary = source("scripts/audit-core-module-boundaries.py")
    smoke = source("scripts/relationship-runtime-coordinator-smoke.swift")
    runner = source("scripts/run-relationship-runtime-coordinator-smoke.sh")
    doctor = source("scripts/doctor.sh")
    ci = source(".github/workflows/ci.yml")
    portable = source("scripts/run-portable-source-smoke.sh")
    builder = source("scripts/build-portable-source.sh")
    auditor = source("scripts/audit-portable-source.py")

    for claim in (
        "final class CompanionRelationshipRuntimeCoordinator: ObservableObject",
        "@Published private(set) var state",
        "@Published private(set) var receipt",
        "private var pendingReceipts",
        "private var momentRecordedAt",
        "private var recentMomentKeys",
        "func forgetAllMemory()",
        "func forgetMemory(",
        "func recordMoment(",
        "func rememberPlayedAsset(",
        "func selectPetMoment(",
        "pendingReceipts.prefix(6)",
        "recentMomentKeys.suffix(8)",
    ):
        require(claim in coordinator, f"focused coordinator lost {claim}")

    for forbidden in (
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "NSWorkspace",
        "NSPasteboard",
        "FileManager",
        "Process(",
        "removeItem(",
        "moveItem(",
        "replaceItemAt(",
    ):
        require(forbidden not in coordinator, f"coordinator gained forbidden side effect {forbidden}")

    require(
        "private let relationshipRuntime" in view_model
        and "CompanionRelationshipRuntimeCoordinator()" in view_model
        and "relationshipRuntime.objectWillChange.sink" in view_model,
        "view model lost the focused relationship-runtime binding",
    )
    for obsolete in (
        "private let relationshipStateStore",
        "private var relationshipReceiptTask",
        "private var relationshipMomentRecordedAt",
        "private var pendingRelationshipReceipts",
        "private var recentPetMomentKeys",
        "private let chemistryInteractionDirector",
        "private var lastReadyRecordedAtByAssetID",
        "enqueueRelationshipReceipts(",
        "presentNextRelationshipReceiptIfNeeded(",
    ):
        require(obsolete not in view_model, f"relationship runtime state returned to composition: {obsolete}")
    require(
        len(view_model.splitlines()) <= 4_151,
        "view-model extraction regressed above the reviewed relationship-runtime migration",
    )

    require(
        "CompanionRelationshipRuntimeCoordinator.swift" in architecture
        and "CompanionRelationshipContentSelection.swift" in architecture
        and "relationship-memory session" in architecture,
        "contributor architecture does not document the relationship runtime",
    )
    require(
        '"CompanionRelationshipRuntimeCoordinator.swift": 280' in boundary,
        "Core boundary audit does not budget the focused coordinator",
    )
    require(
        '"CompanionRelationshipContentSelection.swift": 80' in boundary
        and "extension CompanionRelationshipRuntimeCoordinator" in selection_adapter
        and "ContentPackSelectionContext(" in selection_adapter,
        "focused content-selection projection is missing or unbudgeted",
    )
    for test_claim in (
        "recent moment history was not bounded",
        "cooldown duplicate was accepted",
        "playback memory survived explicit deletion",
        "rollback data survived explicit deletion",
    ):
        require(test_claim in smoke, f"behavior smoke lost: {test_claim}")
    require(
        "CompanionRelationshipRuntimeCoordinator.swift" in runner
        and "relationship-runtime-coordinator-smoke.swift" in runner,
        "runtime smoke runner lost its focused sources",
    )

    for surface_name, surface in (
        ("Doctor", doctor),
        ("CI", ci),
        ("portable smoke", portable),
    ):
        require(
            "check-relationship-runtime-integration.py" in surface
            and "run-relationship-runtime-coordinator-smoke.sh" in surface,
            f"{surface_name} does not execute both relationship runtime guards",
        )
    for surface_name, surface in (("source builder", builder), ("source auditor", auditor)):
        for required in (
            "CompanionRelationshipRuntimeCoordinator.swift",
            "CompanionRelationshipContentSelection.swift",
            "check-relationship-runtime-integration.py",
            "run-relationship-runtime-coordinator-smoke.sh",
            "relationship-runtime-coordinator-smoke.swift",
        ):
            require(required in surface, f"{surface_name} does not require {required}")

    print(
        "PASS  relationship-runtime integration: bounded private memory, "
        "feedback queue, cooldowns, playback anti-repetition and explicit deletion"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
