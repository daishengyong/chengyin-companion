#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Foundation

/// The single application-facing boundary for local content and portable
/// backups. UI state never reaches into the transactional store directly.
///
/// Every mutating operation returns a fresh inventory snapshot so callers do
/// not accidentally render stale pack state after install, rollback, recovery,
/// or playback-health changes.
actor CompanionContentLibrary {
    private let store: ContentPackStore
    private let backupService: CompanionBackupService
    private let archiveImporter: ContentPackArchiveImporter

    init(
        root: URL,
        currentAppVersion: String,
        mediaProbe: any ContentPackMediaProbing = AVFoundationContentPackMediaProbe(),
        signatureVerifier: (any ContentPackSignatureVerifying)? = nil,
        entitlementChecker: (any ContentPackEntitlementChecking)? = nil,
        archiveImporter: ContentPackArchiveImporter = ContentPackArchiveImporter()
    ) {
        let store = ContentPackStore(
            root: root,
            currentAppVersion: currentAppVersion,
            mediaProbe: mediaProbe,
            signatureVerifier: signatureVerifier,
            entitlementChecker: entitlementChecker
        )
        self.store = store
        self.archiveImporter = archiveImporter
        backupService = CompanionBackupService(
            packStore: store,
            appVersion: currentAppVersion
        )
    }

    func install(
        from source: URL
    ) async throws -> CompanionContentInstallSnapshot {
        let values = try source.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        let result: ContentPackInstallResult
        if values.isDirectory == true && values.isSymbolicLink != true {
            result = try await store.install(from: source)
        } else {
            let extraction = try archiveImporter.extract(from: source)
            defer { archiveImporter.removeExtraction(extraction) }
            result = try await store.install(from: extraction.packageDirectory)
        }
        return (result, try await store.inventory())
    }

    func rollback(
        packID: String
    ) async throws -> CompanionContentPackSnapshot {
        let pack = try await store.rollback(packID: packID)
        return (pack, try await store.inventory())
    }

    func remove(
        packID: String
    ) async throws -> CompanionContentRemovalSnapshot {
        let receipt = try await store.remove(packID: packID)
        let snapshot = try await store.snapshot()
        return (
            receipt,
            snapshot.inventory,
            snapshot.recovery
        )
    }

    func restoreRemoval(
        _ receipt: ContentPackRemovalReceipt
    ) async throws -> CompanionContentRestoreSnapshot {
        let pack = try await store.restoreRemoval(receipt)
        let snapshot = try await store.snapshot()
        return (
            pack,
            snapshot.inventory,
            snapshot.recovery
        )
    }

    func restoreRecoveryItem(
        id: String
    ) async throws -> CompanionContentRestoreSnapshot {
        let pack = try await store.restoreRecoveryItem(id: id)
        let snapshot = try await store.snapshot()
        return (
            pack,
            snapshot.inventory,
            snapshot.recovery
        )
    }

    func purgeRecoveryItem(
        id: String
    ) async throws -> CompanionContentRecoverySnapshot {
        try await store.purgeRecoveryItem(id: id)
        let snapshot = try await store.snapshot()
        return (snapshot.inventory, snapshot.recovery)
    }

    func exportBackup(
        to destination: URL,
        settings: CompanionSettingsV1
    ) async throws -> CompanionBackupManifestV1 {
        try await backupService.export(to: destination, settings: settings)
    }

    func inspectBackup(at directory: URL) async throws -> CompanionBackupManifestV1 {
        try await backupService.inspect(at: directory)
    }

    func restoreBackup(
        from directory: URL
    ) async throws -> CompanionContentBackupRestoreSnapshot {
        let result = try await backupService.restore(from: directory)
        return (result, try await store.inventory())
    }

    func recoverInterruptedInstalls() async throws -> CompanionContentMaintenanceSnapshot {
        let cleaned = try await store.recoverInterruptedInstalls()
        let snapshot = try await store.snapshot()
        return (
            cleaned,
            snapshot.inventory,
            snapshot.recovery
        )
    }

    func reportPlayback(
        reference: ContentPackPlaybackReference,
        succeeded: Bool
    ) async throws -> [InstalledContentPack] {
        if succeeded {
            _ = try await store.markPlaybackSucceeded(
                packID: reference.packID,
                version: reference.version
            )
        } else {
            _ = try await store.reportPlaybackFailure(
                packID: reference.packID,
                version: reference.version
            )
        }
        return try await store.inventory()
    }
}
