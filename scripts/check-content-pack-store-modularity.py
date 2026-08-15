#!/usr/bin/env python3
"""Keep content-pack data contracts and durability primitives reviewable."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    print(f"FAIL  content-pack store modularity: {message}", file=sys.stderr)
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
    store = source("Sources/CompanionApp/ContentPackStore.swift")
    repository = source("Sources/CompanionApp/ContentPackStoreRepository.swift")
    layout = source("Sources/CompanionApp/ContentPackStoreLayout.swift")
    active_records = source(
        "Sources/CompanionApp/ContentPackActiveRecordRepository.swift"
    )
    lock_coordinator = source(
        "Sources/CompanionApp/ContentPackStoreLockCoordinator.swift"
    )
    preflight = source("Sources/CompanionApp/ContentPackInstallPreflight.swift")
    install_transactions = source(
        "Sources/CompanionApp/ContentPackInstallTransactions.swift"
    )
    recovery = source("Sources/CompanionApp/ContentPackRecoveryTransactions.swift")
    playback_health = source(
        "Sources/CompanionApp/ContentPackPlaybackHealthTransactions.swift"
    )
    snapshot_projection = source(
        "Sources/CompanionApp/ContentPackStoreSnapshotProjection.swift"
    )
    maintenance = source(
        "Sources/CompanionApp/ContentPackStoreMaintenanceTransactions.swift"
    )
    models = source("Sources/CompanionApp/ContentPackStoreModels.swift")
    durability = source("Sources/CompanionApp/ContentPackStoreDurability.swift")
    library_models = source("Sources/CompanionApp/CompanionContentLibraryModels.swift")
    library = source("Sources/CompanionApp/CompanionContentLibrary.swift")
    architecture = source("docs/CONTRIBUTOR-ARCHITECTURE.md")
    boundary = source("scripts/audit-core-module-boundaries.py")
    smoke_runner = source("scripts/run-content-pack-smoke.sh")
    smoke = source("scripts/content-pack-smoke.swift")
    doctor = source("scripts/doctor.sh")
    ci = source(".github/workflows/ci.yml")
    portable = source("scripts/run-portable-source-smoke.sh")
    source_builder = source("scripts/build-portable-source.sh")
    source_auditor = source("scripts/audit-portable-source.py")

    require("actor ContentPackStore" in store, "transactional actor boundary is missing")
    require(
        "private let repository: ContentPackStoreRepository" in store,
        "transaction actor bypasses the focused storage repository",
    )
    for moved in (
        "enum ContentPackStoreError",
        "struct ActiveContentPackRecord",
        "protocol ContentPackSignatureVerifying",
        "final class ContentPackStoreFileLock",
        "enum ContentPackAtomicFileWriter",
        "private let root: URL",
        "private var packsRoot: URL",
        "private func readActiveRecord(",
        "private func writeActiveRecord(",
        "ContentPackAtomicFileWriter.write(",
        "ContentPackStoreFileLock.acquire(",
        "repository.acquireStoreLock(",
        "private func restoreRemovalLocked(",
        "repository.recoveryCatalog",
        "lstat(",
        "flock(",
        "rename(",
    ):
        require(moved not in store, f"focused declaration returned to the actor file: {moved}")
    require(
        "private let installPreflight: ContentPackInstallPreflight" in store,
        "transaction actor bypasses the focused install preflight",
    )
    require(
        "private let installTransactions: ContentPackInstallTransactions" in store
        and "installTransactions.stage(" in store
        and "installTransactions.commit(" in store
        and "installTransactions.discard(" in store,
        "transaction actor bypasses lock-scoped staging, commit or cleanup",
    )
    require(
        "private let recoveryTransactions: ContentPackRecoveryTransactions" in store,
        "transaction actor bypasses the lock-scoped recovery component",
    )
    require(
        "private let playbackHealthTransactions: ContentPackPlaybackHealthTransactions"
        in store,
        "transaction actor bypasses the lock-scoped playback-health component",
    )
    require(
        "private let snapshotProjection: ContentPackStoreSnapshotProjection" in store
        and "func snapshot() throws -> ContentPackStoreSnapshot" in store,
        "transaction actor bypasses the lock-scoped content snapshot projection",
    )
    require(
        "private let maintenanceTransactions: ContentPackStoreMaintenanceTransactions"
        in store
        and "maintenanceTransactions.rollback(" in store
        and "maintenanceTransactions.recoverInterruptedInstalls(" in store,
        "transaction actor bypasses lock-scoped rollback or staging maintenance",
    )
    for moved_health_policy in (
        "guard current.health == .pendingHealth",
        "ContentPackStoreError.activeVersionChanged(",
        "let replacement: ActiveContentPackRecord",
    ):
        require(
            moved_health_policy not in store,
            f"playback-health policy returned to the actor: {moved_health_policy}",
        )
    require(
        "repository.withStoreLock" in store and "mediaProbe.probe(" in store,
        "transaction actor lost its synchronous-lock/async-probe split",
    )
    for moved_maintenance_policy in (
        "let target = repository.versionDirectory(",
        "let candidates = try repository.fileManager.contentsOfDirectory(",
        'candidate.lastPathComponent.hasSuffix(".staging")',
    ):
        require(
            moved_maintenance_policy not in store,
            f"maintenance policy returned to the actor: {moved_maintenance_policy}",
        )
    for moved_install_policy in (
        "repository.fileManager.copyItem(",
        "repository.fileManager.moveItem(",
        "repository.fileManager.removeItem(",
        "repository.writeActiveRecord(",
        "var committedVersionDirectory",
        "var activationCompleted",
    ):
        require(
            moved_install_policy not in store,
            f"install mutation returned to the actor: {moved_install_policy}",
        )
    require(len(store.splitlines()) <= 300, "transaction actor grew above its reviewed 300-line budget")

    for claim in (
        "struct ContentPackStoreRepository",
        "private let layout: ContentPackStoreLayout",
        "private let activeRecords: ContentPackActiveRecordRepository",
        "private let lockCoordinator: ContentPackStoreLockCoordinator",
        "var packsRoot: URL",
        "var stagingRoot: URL",
        "var removedRoot: URL",
        "func prepareStore()",
        "func readActiveRecord(",
        "func writeActiveRecord(",
        "func installedPack(",
        "try layout.prepareStore()",
        "try activeRecords.read(packID: packID)",
        "try activeRecords.write(record)",
        "try activeRecords.installedPack(for: record)",
        "try lockCoordinator.withLock(operation)",
        "func withStoreLock<Result>(",
    ):
        require(claim in repository, f"storage facade lost {claim}")
    for forbidden in (
        "JSONDecoder",
        "JSONEncoder",
        "ContentPackAtomicFileWriter.write(",
        "ContentPackStoreFileLock.acquire(",
        "ContentPackStoreLockScope()",
        "createDirectory(",
        "func install(",
        "func rollback(",
        "func remove(",
        "func markPlaybackSucceeded(",
        "func reportPlaybackFailure(",
        "func authorize(",
        "mediaProbe",
        "signatureVerifier",
        "entitlementChecker",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        require(forbidden not in repository, f"storage facade remerged another capability: {forbidden}")
    require(len(repository.splitlines()) <= 120, "storage facade grew above its reviewed 120-line budget")

    for claim in (
        "struct ContentPackStoreLayout",
        "root.standardizedFileURL",
        "var packsRoot: URL",
        "var stagingRoot: URL",
        "var removedRoot: URL",
        "func packDirectory(",
        "func versionDirectory(",
        "func prepareStore()",
        "func createPrivateDirectory(",
        "fileManager.createDirectory(",
        ".posixPermissions: 0o700",
    ):
        require(claim in layout, f"store layout lost {claim}")
    for forbidden in (
        "JSONDecoder",
        "JSONEncoder",
        "ContentPackValidator",
        "ContentPackStoreFileLock",
        "ContentPackStoreLockScope",
        "ActiveContentPackRecord",
        "InstalledContentPack",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        require(forbidden not in layout, f"store layout gained unrelated capability: {forbidden}")
    require(len(layout.splitlines()) <= 80, "store layout exceeded its reviewed 80-line budget")

    for claim in (
        "struct ContentPackActiveRecordRepository",
        "func validateIdentifier(",
        "func read(packID:",
        "func write(_ record:",
        "func installedPack(",
        "ActiveContentPackRecord.currentSchemaVersion",
        "record.packID == packID",
        "SemanticVersion(record.version)",
        "decoder.dateDecodingStrategy = .iso8601",
        "encoder.dateEncodingStrategy = .iso8601",
        "ContentPackAtomicFileWriter.write(",
        "validator.loadAndValidate(",
        "manifest.id == record.packID",
        "manifest.version == record.version",
    ):
        require(claim in active_records, f"active-record repository lost {claim}")
    for forbidden in (
        "ContentPackStoreFileLock",
        "ContentPackStoreLockScope",
        "func prepareStore(",
        "var packsRoot:",
        "var stagingRoot:",
        "var removedRoot:",
        "func install(",
        "func rollback(",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        require(forbidden not in active_records, f"active-record repository gained unrelated capability: {forbidden}")
    require(len(active_records.splitlines()) <= 110, "active-record repository exceeded its reviewed 110-line budget")

    for claim in (
        "struct ContentPackStoreLockScope",
        "fileprivate init() {}",
        "struct ContentPackStoreLockCoordinator",
        "ContentPackStoreFileLock.acquire(",
        'appendingPathComponent(".pack-store.lock")',
        "defer { storeLock.release() }",
        "ContentPackStoreLockScope()",
    ):
        require(claim in lock_coordinator, f"store lock coordinator lost {claim}")
    for forbidden in (
        "JSONDecoder",
        "JSONEncoder",
        "ContentPackValidator",
        "FileManager",
        "createDirectory(",
        "ActiveContentPackRecord",
        "InstalledContentPack",
        "async ",
        "await ",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        require(forbidden not in lock_coordinator, f"store lock coordinator gained unrelated capability: {forbidden}")
    require(len(lock_coordinator.splitlines()) <= 60, "store lock coordinator exceeded its reviewed 60-line budget")

    scope_constructors = []
    for path in sorted((ROOT / "Sources/CompanionApp").glob("*.swift")):
        if "ContentPackStoreLockScope()" in path.read_text(encoding="utf-8"):
            scope_constructors.append(path.name)
    require(
        scope_constructors == ["ContentPackStoreLockCoordinator.swift"],
        "store-lock scope can be forged outside its coordinator",
    )

    for claim in (
        "struct ContentPackInstallPreflight",
        "func loadCandidateManifest(",
        "func validateCandidate(",
        "func validateVersionTransition(",
        "func activationRecord(",
        "private func authorize(",
        "signatureVerifier",
        "entitlementChecker",
        "ContentPackValidator.sha256(",
    ):
        require(claim in preflight, f"focused install preflight lost {claim}")
    for forbidden in (
        "copyItem(",
        "moveItem(",
        "removeItem(",
        "writeActiveRecord(",
        "createPrivateDirectory(",
        "acquireStoreLock(",
        "withStoreLock",
        "ContentPackAtomicFileWriter",
        "mediaProbe",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        require(forbidden not in preflight, f"read-only install preflight gained side effect: {forbidden}")
    require(len(preflight.splitlines()) <= 140, "install preflight grew above its reviewed 140-line budget")

    for claim in (
        "struct ContentPackInstallTransactions",
        "let repository: ContentPackStoreRepository",
        "let preflight: ContentPackInstallPreflight",
        "func stage(",
        "func commit(",
        "func discard(",
        "lockedBy scope: ContentPackStoreLockScope",
        "repository.fileManager.copyItem(",
        "preflight.validateCandidate(",
        "preflight.validateVersionTransition(",
        "repository.fileManager.moveItem(",
        "repository.writeActiveRecord(",
        "private func discardOwnedStaging(",
        'normalized.lastPathComponent.hasSuffix(".staging")',
    ):
        require(claim in install_transactions, f"install transactions lost {claim}")
    for forbidden in (
        "withStoreLock",
        "acquireStoreLock(",
        "ContentPackStoreFileLock",
        "async ",
        "await ",
        "mediaProbe",
        "signatureVerifier",
        "entitlementChecker",
        "repository.removedRoot",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        require(
            forbidden not in install_transactions,
            f"install transactions gained unrelated capability: {forbidden}",
        )
    require(
        install_transactions.count("lockedBy scope: ContentPackStoreLockScope") == 3,
        "staging, commit or cleanup lost the store-lock capability",
    )
    require(
        len(install_transactions.splitlines()) <= 180,
        "install transactions grew above their reviewed 180-line budget",
    )
    install_transaction_owners = []
    for path in sorted((ROOT / "Sources/CompanionApp").glob("*.swift")):
        if "ContentPackInstallTransactions(" in path.read_text(encoding="utf-8"):
            install_transaction_owners.append(path.name)
    require(
        install_transaction_owners == ["ContentPackStore.swift"],
        "install transaction capability is constructed outside ContentPackStore",
    )

    for claim in (
        "struct ContentPackRecoveryTransactions",
        "let repository: ContentPackStoreRepository",
        "func restoreAfterFailedBatch(",
        "func remove(",
        "func inventory(",
        "func restoreItem(",
        "func purgeItem(",
        "func restoreRemoval(",
        "lockedBy scope: ContentPackStoreLockScope",
        "repository.recoveryCatalog",
        "repository.writeActiveRecord(",
        "lstat(",
    ):
        require(claim in recovery, f"focused recovery transactions lost {claim}")
    for forbidden in (
        "withStoreLock",
        "acquireStoreLock(",
        "ContentPackStoreFileLock",
        "async ",
        "await ",
        "mediaProbe",
        "signatureVerifier",
        "entitlementChecker",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        require(forbidden not in recovery, f"recovery transactions gained unrelated capability: {forbidden}")
    require(len(recovery.splitlines()) <= 180, "recovery transactions grew above their reviewed 180-line budget")
    require(
        recovery.count("lockedBy scope: ContentPackStoreLockScope") == 6,
        "one or more recovery mutations lost the store-lock scope capability",
    )

    recovery_owners = []
    for path in sorted((ROOT / "Sources/CompanionApp").glob("*.swift")):
        if "ContentPackRecoveryTransactions(" in path.read_text(encoding="utf-8"):
            recovery_owners.append(path.name)
    require(
        recovery_owners == ["ContentPackStore.swift"],
        "recovery transaction capability is constructed outside ContentPackStore",
    )

    for claim in (
        "struct ContentPackPlaybackHealthTransactions",
        "let repository: ContentPackStoreRepository",
        "func markSucceeded(",
        "func reportFailure(",
        "private func activeRecord(",
        "lockedBy scope: ContentPackStoreLockScope",
        "guard current.health == .pendingHealth",
        "health: .healthy",
        "health: .disabled",
        "repository.writeActiveRecord(",
        "repository.validator.loadAndValidate(",
    ):
        require(claim in playback_health, f"playback-health transactions lost {claim}")
    for forbidden in (
        "withStoreLock",
        "acquireStoreLock(",
        "ContentPackStoreFileLock",
        "async ",
        "await ",
        "mediaProbe",
        "signatureVerifier",
        "entitlementChecker",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        require(
            forbidden not in playback_health,
            f"playback-health transactions gained unrelated capability: {forbidden}",
        )
    require(
        len(playback_health.splitlines()) <= 140,
        "playback-health transactions grew above their reviewed 140-line budget",
    )
    require(
        playback_health.count("lockedBy scope: ContentPackStoreLockScope") == 2,
        "one or more playback-health mutations lost the store-lock capability",
    )
    playback_health_owners = []
    for path in sorted((ROOT / "Sources/CompanionApp").glob("*.swift")):
        if "ContentPackPlaybackHealthTransactions(" in path.read_text(encoding="utf-8"):
            playback_health_owners.append(path.name)
    require(
        playback_health_owners == ["ContentPackStore.swift"],
        "playback-health transaction capability is constructed outside ContentPackStore",
    )

    for claim in (
        "struct ContentPackStoreSnapshotProjection",
        "let repository: ContentPackStoreRepository",
        "let recoveryTransactions: ContentPackRecoveryTransactions",
        "func inventory(",
        "func snapshot(",
        "lockedBy scope: ContentPackStoreLockScope",
        "let directories = try repository.fileManager.contentsOfDirectory(",
        "recoveryTransactions.inventory(lockedBy: scope)",
    ):
        require(claim in snapshot_projection, f"content snapshot projection lost {claim}")
    for forbidden in (
        "withStoreLock",
        "acquireStoreLock(",
        "writeActiveRecord(",
        "copyItem(",
        "moveItem(",
        "removeItem(",
        "async ",
        "await ",
        "mediaProbe",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        require(
            forbidden not in snapshot_projection,
            f"content snapshot projection gained unrelated capability: {forbidden}",
        )
    require(
        snapshot_projection.count("lockedBy scope: ContentPackStoreLockScope") == 2,
        "content snapshot reads lost the store-lock capability",
    )
    require(
        len(snapshot_projection.splitlines()) <= 120,
        "content snapshot projection grew above its reviewed 120-line budget",
    )
    snapshot_owners = []
    for path in sorted((ROOT / "Sources/CompanionApp").glob("*.swift")):
        if "ContentPackStoreSnapshotProjection(" in path.read_text(encoding="utf-8"):
            snapshot_owners.append(path.name)
    require(
        snapshot_owners == ["ContentPackStore.swift"],
        "content snapshot projection is constructed outside ContentPackStore",
    )

    for claim in (
        "struct ContentPackStoreMaintenanceTransactions",
        "let repository: ContentPackStoreRepository",
        "func rollback(",
        "func recoverInterruptedInstalls(",
        "lockedBy scope: ContentPackStoreLockScope",
        "let target = repository.versionDirectory(",
        "repository.validator.loadAndValidate(",
        "repository.writeActiveRecord(",
        "at: repository.stagingRoot",
        'candidate.lastPathComponent.hasSuffix(".staging")',
    ):
        require(claim in maintenance, f"maintenance transactions lost {claim}")
    for forbidden in (
        "withStoreLock",
        "acquireStoreLock(",
        "ContentPackStoreFileLock",
        "repository.packsRoot",
        "repository.removedRoot",
        "async ",
        "await ",
        "mediaProbe",
        "signatureVerifier",
        "entitlementChecker",
        "import AppKit",
        "import SwiftUI",
        "URLSession",
        "Process(",
    ):
        require(
            forbidden not in maintenance,
            f"maintenance transactions gained unrelated capability: {forbidden}",
        )
    require(
        maintenance.count("lockedBy scope: ContentPackStoreLockScope") == 2,
        "rollback or interrupted-install cleanup lost the store-lock capability",
    )
    require(
        len(maintenance.splitlines()) <= 120,
        "maintenance transactions grew above their reviewed 120-line budget",
    )
    maintenance_owners = []
    for path in sorted((ROOT / "Sources/CompanionApp").glob("*.swift")):
        if "ContentPackStoreMaintenanceTransactions(" in path.read_text(encoding="utf-8"):
            maintenance_owners.append(path.name)
    require(
        maintenance_owners == ["ContentPackStore.swift"],
        "maintenance transaction capability is constructed outside ContentPackStore",
    )

    for claim in (
        "enum ContentPackInstallCheckpoint",
        "enum ContentPackStoreError: LocalizedError",
        "var companionErrorCode: String",
        "protocol ContentPackSignatureVerifying: Sendable",
        "protocol ContentPackEntitlementChecking: Sendable",
        "enum ContentPackHealthStatus",
        "enum ContentPackQualityLevel",
        "struct ActiveContentPackRecord",
        "struct InstalledContentPack",
        "struct ContentPackInstallResult",
        "struct ContentPackStoreSnapshot",
        "struct ContentPackRemovalReceipt",
    ):
        require(claim in models, f"focused store models lost {claim}")
    for forbidden in (
        "import Darwin",
        "import AppKit",
        "import SwiftUI",
        "FileManager",
        "UserDefaults",
        "URLSession",
        "Process(",
        "removeItem(",
        "moveItem(",
        "flock(",
    ):
        require(forbidden not in models, f"data/error contract gained side effect: {forbidden}")
    require(len(models.splitlines()) <= 220, "store models grew above their reviewed 220-line budget")

    for claim in (
        "typealias CompanionContentInstallSnapshot",
        "typealias CompanionContentPackSnapshot",
        "typealias CompanionContentRemovalSnapshot",
        "typealias CompanionContentRestoreSnapshot",
        "typealias CompanionContentRecoverySnapshot",
        "typealias CompanionContentBackupRestoreSnapshot",
        "typealias CompanionContentMaintenanceSnapshot",
    ):
        require(claim in library_models, f"content-library result models lost {claim}")
    for forbidden in (
        "actor ",
        "class ",
        "func ",
        "async ",
        "await ",
        "FileManager",
        "URLSession",
        "Process(",
    ):
        require(forbidden not in library_models, f"content-library result models gained behavior: {forbidden}")
    require(len(library_models.splitlines()) <= 100, "content-library result models exceeded 100 lines")
    require(
        "store.snapshot()" in library and "store.recoveryInventory()" not in library,
        "application content library rebuilds active/recovery state from separate actor calls",
    )
    require(len(library.splitlines()) <= 170, "application content library exceeded 170 lines")

    for claim in (
        "final class ContentPackStoreFileLock",
        "flock(descriptor, LOCK_EX)",
        "enum ContentPackAtomicFileWriter",
        "O_CREAT | O_EXCL | O_WRONLY",
        "fsync(descriptor)",
        "rename(temporary.path, destination.path)",
        "fsync(parentDescriptor)",
        "unlink(temporary.path)",
    ):
        require(claim in durability, f"durability primitive lost {claim}")
    for forbidden in (
        "import AppKit",
        "import SwiftUI",
        "FileManager",
        "UserDefaults",
        "URLSession",
        "Process(",
    ):
        require(forbidden not in durability, f"durability primitive gained unrelated capability: {forbidden}")
    require(len(durability.splitlines()) <= 140, "durability primitives grew above their reviewed 140-line budget")

    require(
        "ContentPackStoreRepository.swift" in architecture
        and "ContentPackStoreLayout.swift" in architecture
        and "ContentPackActiveRecordRepository.swift" in architecture
        and "ContentPackStoreLockCoordinator.swift" in architecture
        and "ContentPackInstallPreflight.swift" in architecture
        and "ContentPackInstallTransactions.swift" in architecture
        and "ContentPackRecoveryTransactions.swift" in architecture
        and "ContentPackPlaybackHealthTransactions.swift" in architecture
        and "ContentPackStoreSnapshotProjection.swift" in architecture
        and "ContentPackStoreMaintenanceTransactions.swift" in architecture
        and "CompanionContentLibraryModels.swift" in architecture
        and "ContentPackStoreModels.swift" in architecture
        and "ContentPackStoreDurability.swift" in architecture
        and "fsync + rename" in architecture,
        "contributor architecture does not document the split transaction boundary",
    )
    for claim in (
        '"ContentPackStore.swift": 300',
        '"ContentPackStoreRepository.swift": 120',
        '"ContentPackStoreLayout.swift": 80',
        '"ContentPackActiveRecordRepository.swift": 110',
        '"ContentPackStoreLockCoordinator.swift": 60',
        '"ContentPackInstallPreflight.swift": 140',
        '"ContentPackInstallTransactions.swift": 180',
        '"ContentPackRecoveryTransactions.swift": 180',
        '"ContentPackPlaybackHealthTransactions.swift": 140',
        '"ContentPackStoreSnapshotProjection.swift": 120',
        '"ContentPackStoreMaintenanceTransactions.swift": 120',
        '"ContentPackStoreModels.swift": 220',
        '"ContentPackStoreDurability.swift": 140',
    ):
        require(claim in boundary, f"Core boundary audit lost focused budget {claim}")
    for required in (
        "ContentPackStoreModels.swift",
        "ContentPackStoreDurability.swift",
        "ContentPackStoreLayout.swift",
        "ContentPackActiveRecordRepository.swift",
        "ContentPackStoreLockCoordinator.swift",
        "ContentPackStoreRepository.swift",
        "ContentPackInstallPreflight.swift",
        "ContentPackInstallTransactions.swift",
        "ContentPackRecoveryTransactions.swift",
        "ContentPackPlaybackHealthTransactions.swift",
        "ContentPackStoreSnapshotProjection.swift",
        "ContentPackStoreMaintenanceTransactions.swift",
        "CompanionContentLibraryModels.swift",
    ):
        require(required in smoke_runner, f"content-pack behavior smoke omits {required}")
    for behavior in (
        "transactional install, upgrade and rollback",
        "staged candidate is revalidated after async media probe",
        "same-version conflict rejected",
        "content store snapshot is coherent under one lock",
        "interrupted staging cleanup is scoped",
        "staging-copy failure leaves no store mutation",
        "atomic pointer lost complete v2",
    ):
        require(behavior in smoke, f"transaction behavior evidence lost {behavior}")
    for surface_name, surface in (
        ("Doctor", doctor),
        ("CI", ci),
        ("portable smoke", portable),
    ):
        require(
            "check-content-pack-store-modularity.py" in surface,
            f"{surface_name} does not execute the store modularity guard",
        )
    for surface_name, surface in (
        ("source builder", source_builder),
        ("source auditor", source_auditor),
    ):
        for required in (
            "ContentPackStoreModels.swift",
            "ContentPackStoreDurability.swift",
            "ContentPackStoreLayout.swift",
            "ContentPackActiveRecordRepository.swift",
            "ContentPackStoreLockCoordinator.swift",
            "ContentPackStoreRepository.swift",
            "ContentPackInstallPreflight.swift",
            "ContentPackInstallTransactions.swift",
            "ContentPackRecoveryTransactions.swift",
            "ContentPackPlaybackHealthTransactions.swift",
            "ContentPackStoreSnapshotProjection.swift",
            "ContentPackStoreMaintenanceTransactions.swift",
            "CompanionContentLibraryModels.swift",
            "check-content-pack-store-modularity.py",
        ):
            require(required in surface, f"{surface_name} does not require {required}")

    print(
        "PASS  content-pack store modularity: synchronous transaction locks, "
        "read-only install preflight, capability-scoped install/recovery/playback health, one-lock content snapshots, "
        "capability-scoped rollback/staging maintenance, isolated layout/record/lock capabilities, data/error contracts and fsync+rename durability primitives"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
