#!/usr/bin/env python3
"""Keep local content transactions out of the primary App composition model."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"FAIL  content-operations integration: {message}", file=sys.stderr)
        raise SystemExit(1)


def source(relative: str) -> str:
    path = ROOT / relative
    require(path.is_file() and not path.is_symlink(), f"missing or unsafe {relative}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    coordinator = source(
        "Sources/CompanionApp/CompanionContentOperationsCoordinator.swift"
    )
    operation_models = source(
        "Sources/CompanionApp/CompanionContentOperationModels.swift"
    )
    receipt_factory = source(
        "Sources/CompanionApp/CompanionContentOperationReceiptFactory.swift"
    )
    backup_coordinator = source(
        "Sources/CompanionApp/CompanionBackupOperationsCoordinator.swift"
    )
    library_models = source("Sources/CompanionApp/CompanionContentLibraryModels.swift")
    library = source("Sources/CompanionApp/CompanionContentLibrary.swift")
    recovery_catalog = source("Sources/CompanionApp/ContentPackRecoveryCatalog.swift")
    recovery_ui = source(
        "Sources/CompanionApp/CompanionContentPackRecoverySection.swift"
    )
    view_model = source("Sources/CompanionApp/CompanionViewModel.swift")
    settings_models = source(
        "Sources/CompanionApp/CompanionSettingsPresentationModels.swift"
    )
    smoke_runner = source("scripts/run-content-pack-smoke.sh")
    smoke = source("scripts/content-pack-smoke.swift")
    doctor = source("scripts/doctor.sh")
    ci = source(".github/workflows/ci.yml")

    for claim in (
        "final class CompanionContentOperationsCoordinator: ObservableObject",
        "private let library: CompanionContentLibrary",
        "private let backupOperations: CompanionBackupOperationsCoordinator",
        "@Published private(set) var contentPackOperationInProgress",
        "private var lastRemovalReceipt: ContentPackRemovalReceipt?",
        "@Published private(set) var contentPackRecoveryItems",
        "func restoreRecoveryItem(id:",
        "func purgeRecoveryItem(id:",
        "startAccessingSecurityScopedResource()",
        "func recoverInterruptedInstalls()",
        "func reportPlayback(",
        "CompanionContentOperationReceiptFactory.failure(",
    ):
        require(claim in coordinator, f"focused coordinator lost {claim}")

    for forbidden in (
        "@Published private(set) var backupOperationInProgress",
        "func beginBackupOperation(",
        "let manifest = try await library.exportBackup(",
        "let manifest = try await library.inspectBackup(",
        "let snapshot = try await library.restoreBackup(",
    ):
        require(forbidden not in coordinator, f"backup ownership returned to content coordinator: {forbidden}")

    for claim in (
        "final class CompanionBackupOperationsCoordinator: ObservableObject",
        "@Published private(set) var operationInProgress",
        "@Published private(set) var pendingPreview",
        "func exportBackup(",
        "func inspectBackup(",
        "func restoreInspectedBackup()",
        "startAccessingSecurityScopedResource()",
        "CompanionContentOperationReceiptFactory.failure(",
    ):
        require(claim in backup_coordinator, f"focused backup coordinator lost {claim}")

    for claim in (
        "enum CompanionContentOperationReceiptFactory",
        "static func success(",
        "static func failure(",
        "CompanionErrorPresentation.message(for: error)",
        "private static func contextualError(",
    ):
        require(claim in receipt_factory, f"path-safe receipt factory lost {claim}")
        require(claim not in coordinator, f"receipt presentation returned to coordinator: {claim}")

    for claim in (
        "enum CompanionContentOperationKind: Equatable",
        "enum CompanionContentOperationSuccess",
        "struct CompanionContentOperationReceipt",
        "struct CompanionContentRecoveryReceipt",
    ):
        require(claim in operation_models, f"focused operation models lost {claim}")
        require(claim not in coordinator, f"operation model returned to coordinator: {claim}")

    require(
        "actor CompanionContentLibrary" in library
        and "Every mutating operation returns a fresh inventory snapshot" in library
        and "store.snapshot()" in library
        and "store.recoveryInventory()" not in library,
        "transactional actor boundary or fresh-inventory contract drifted",
    )
    for claim in (
        "typealias CompanionContentInstallSnapshot",
        "typealias CompanionContentRemovalSnapshot",
        "typealias CompanionContentRestoreSnapshot",
        "typealias CompanionContentRecoverySnapshot",
        "typealias CompanionContentMaintenanceSnapshot",
    ):
        require(claim in library_models, f"content-library result model lost {claim}")
        require(claim not in library, f"content-library result model returned to actor: {claim}")
    require(len(library.splitlines()) <= 170, "content library exceeded its reviewed 170-line budget")
    for claim in (
        "struct ContentPackRecoveryItem: Identifiable, Equatable, Sendable",
        "static let maximumItems = 128",
        "func resolveEntry(id: String)",
        "PACK_RECOVERY_SYMLINK_ENTRY",
    ):
        require(claim in recovery_catalog, f"recovery catalog lost {claim}")
    require(
        "struct CompanionContentPackRecoverySection: View" in recovery_ui
        and "contentPackRecovery.restore" in recovery_ui
        and "contentPackRecovery.purge" in recovery_ui
        and "confirmationDialog" in recovery_ui,
        "restart recovery UI or destructive confirmation is missing",
    )
    require(
        "private let contentOperations: CompanionContentOperationsCoordinator"
        in view_model
        and "contentOperations.objectWillChange.sink" in view_model
        and "applyContentOperationReceipt" in view_model,
        "view model is not binding the focused operation coordinator",
    )
    for forbidden in (
        "private let contentLibrary: CompanionContentLibrary",
        "CompanionContentLibrary(\n",
        "startAccessingSecurityScopedResource()",
        "lastContentPackRemovalReceipt",
        "contentPackOperationInProgress = true",
        "backupOperationInProgress = true",
    ):
        require(
            forbidden not in view_model,
            f"content transaction state returned to the view model: {forbidden}",
        )

    require(
        "struct CompanionBackupPreview: Equatable" in settings_models,
        "portable backup preview contract is missing",
    )
    require(
        "CompanionContentOperationsCoordinator.swift" in smoke_runner
        and "CompanionContentOperationModels.swift" in smoke_runner
        and "CompanionContentOperationReceiptFactory.swift" in smoke_runner
        and "CompanionBackupOperationsCoordinator.swift" in smoke_runner
        and "CompanionContentLibraryModels.swift" in smoke_runner
        and "ContentPackStoreSnapshotProjection.swift" in smoke_runner
        and "CompanionSettingsPresentationModels.swift" in smoke_runner,
        "content-pack smoke does not compile the focused coordinator",
    )
    for behavior in (
        "content operations coordinate state and safe receipts",
        "recovery catalog survives restart",
        "recovery identifier traversal rejected",
        "damaged recovery item is isolated",
        "failed restore remains recoverable for cleanup",
        "recovery symlink cannot escape purge boundary",
        "recovery inventory is bounded",
        "content store snapshot is coherent under one lock",
        "coordinator left install progress active",
        "coordinator did not expose recoverable removal",
        "coordinator retained a consumed removal receipt",
        "coordinator restart lost the persistent recovery inventory",
        "coordinator returned the wrong purge receipt",
        "coordinator failure lost its stable code",
        "coordinator failure disclosed a local path",
    ):
        require(behavior in smoke, f"transaction behavior smoke lost {behavior}")
    require(
        "check-content-operations-integration.py" in doctor
        and "check-content-operations-integration.py" in ci,
        "doctor or CI does not execute the content-operations guard",
    )

    print(
        "PASS  content-operations integration: transactional actor, focused "
        "content and backup MainActor state, cross-restart recovery, scoped backup "
        "and shared path-safe receipts"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
