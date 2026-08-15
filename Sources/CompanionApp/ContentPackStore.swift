import Foundation

/// Actor-isolated store that validates, stages and commits immutable pack
/// versions before atomically changing the active pointer.
actor ContentPackStore {
    private let repository: ContentPackStoreRepository
    private let installPreflight: ContentPackInstallPreflight
    private let installTransactions: ContentPackInstallTransactions
    private let recoveryTransactions: ContentPackRecoveryTransactions
    private let playbackHealthTransactions: ContentPackPlaybackHealthTransactions
    private let snapshotProjection: ContentPackStoreSnapshotProjection
    private let maintenanceTransactions: ContentPackStoreMaintenanceTransactions
    private let mediaProbe: any ContentPackMediaProbing

    init(
        root: URL,
        currentAppVersion: String,
        fileManager: FileManager = .default,
        mediaProbe: any ContentPackMediaProbing = AVFoundationContentPackMediaProbe(),
        signatureVerifier: (any ContentPackSignatureVerifying)? = nil,
        entitlementChecker: (any ContentPackEntitlementChecking)? = nil
    ) {
        let repository = ContentPackStoreRepository(
            root: root,
            currentAppVersion: currentAppVersion,
            fileManager: fileManager
        )
        self.repository = repository
        let installPreflight = ContentPackInstallPreflight(
            repository: repository,
            signatureVerifier: signatureVerifier,
            entitlementChecker: entitlementChecker
        )
        self.installPreflight = installPreflight
        installTransactions = ContentPackInstallTransactions(
            repository: repository,
            preflight: installPreflight
        )
        let recoveryTransactions = ContentPackRecoveryTransactions(
            repository: repository
        )
        self.recoveryTransactions = recoveryTransactions
        playbackHealthTransactions = ContentPackPlaybackHealthTransactions(
            repository: repository
        )
        snapshotProjection = ContentPackStoreSnapshotProjection(
            repository: repository,
            recoveryTransactions: recoveryTransactions
        )
        maintenanceTransactions = ContentPackStoreMaintenanceTransactions(
            repository: repository
        )
        self.mediaProbe = mediaProbe
    }

    func install(
        from packageDirectory: URL,
        failAt checkpoint: ContentPackInstallCheckpoint? = nil
    ) async throws -> ContentPackInstallResult {
        try repository.prepareStore()
        let sourceManifest = try installPreflight.loadCandidateManifest(
            at: packageDirectory
        )

        let stagingDirectory = try repository.withStoreLock { scope in
            try installTransactions.stage(
                packageDirectory: packageDirectory,
                failAt: checkpoint,
                lockedBy: scope
            )
        }

        do {
            let stagedManifest = try installPreflight.validateCandidate(
                at: stagingDirectory,
                expectedManifest: sourceManifest
            )
            try await mediaProbe.probe(
                packageDirectory: stagingDirectory,
                manifest: stagedManifest
            )
            try installTransactions.inject(
                checkpoint,
                at: .afterStagingValidation
            )

            return try repository.withStoreLock { scope in
                try installTransactions.commit(
                    stagingDirectory: stagingDirectory,
                    expectedManifest: stagedManifest,
                    failAt: checkpoint,
                    lockedBy: scope
                )
            }
        } catch {
            try? repository.withStoreLock { scope in
                try installTransactions.discard(
                    stagingDirectory: stagingDirectory,
                    lockedBy: scope
                )
            }
            throw error
        }
    }

    /// Performs every deterministic validation used by installation without
    /// staging, committing a version or changing the active pointer. Batch
    /// restore uses this to reject a bad backup before the first pack mutates
    /// the destination store; install still repeats validation to close races.
    func preflightInstall(from packageDirectory: URL) async throws -> ContentPackManifest {
        try repository.prepareStore()
        let manifest = try installPreflight.validateCandidate(
            at: packageDirectory
        )
        try await mediaProbe.probe(
            packageDirectory: packageDirectory,
            manifest: manifest
        )
        return try repository.withStoreLock { _ in
            let revalidated = try installPreflight.validateCandidate(
                at: packageDirectory,
                expectedManifest: manifest
            )
            let prior = try repository.readActiveRecord(packID: revalidated.id)
            try installPreflight.validateVersionTransition(
                manifest: revalidated,
                candidateDirectory: packageDirectory,
                priorRecord: prior
            )
            return revalidated
        }
    }

    /// Restores an exact active pointer captured before a failed batch. A pack
    /// that did not exist before the batch is moved into the recovery area.
    func restoreAfterFailedBatch(
        packID: String,
        priorRecord: ActiveContentPackRecord?
    ) throws {
        try repository.prepareStore()
        try repository.withStoreLock { scope in
            try recoveryTransactions.restoreAfterFailedBatch(
                packID: packID,
                priorRecord: priorRecord,
                lockedBy: scope
            )
        }
    }

    func activePack(id packID: String) throws -> InstalledContentPack {
        try repository.prepareStore()
        try repository.validateIdentifier(packID)
        guard let record = try repository.readActiveRecord(packID: packID) else {
            throw ContentPackStoreError.noActivePack(packID)
        }
        return try repository.installedPack(for: record)
    }

    func inventory() throws -> [InstalledContentPack] {
        try repository.prepareStore()
        return try repository.withStoreLock { scope in
            try snapshotProjection.inventory(lockedBy: scope)
        }
    }

    func snapshot() throws -> ContentPackStoreSnapshot {
        try repository.prepareStore()
        return try repository.withStoreLock { scope in
            try snapshotProjection.snapshot(lockedBy: scope)
        }
    }

    @discardableResult
    func rollback(packID: String) throws -> InstalledContentPack {
        try repository.prepareStore()
        return try repository.withStoreLock { scope in
            try maintenanceTransactions.rollback(
                packID: packID,
                lockedBy: scope
            )
        }
    }

    func remove(packID: String) throws -> ContentPackRemovalReceipt {
        try repository.prepareStore()
        return try repository.withStoreLock { scope in
            try recoveryTransactions.remove(
                packID: packID,
                lockedBy: scope
            )
        }
    }

    func recoveryInventory() throws -> [ContentPackRecoveryItem] {
        try repository.prepareStore()
        return try repository.withStoreLock { scope in
            try recoveryTransactions.inventory(lockedBy: scope)
        }
    }

    @discardableResult
    func restoreRecoveryItem(id: String) throws -> InstalledContentPack {
        try repository.prepareStore()
        return try repository.withStoreLock { scope in
            try recoveryTransactions.restoreItem(id: id, lockedBy: scope)
        }
    }

    func purgeRecoveryItem(id: String) throws {
        try repository.prepareStore()
        try repository.withStoreLock { scope in
            try recoveryTransactions.purgeItem(id: id, lockedBy: scope)
        }
    }

    @discardableResult
    func restoreRemoval(_ receipt: ContentPackRemovalReceipt) throws -> InstalledContentPack {
        try repository.prepareStore()
        return try repository.withStoreLock { scope in
            try recoveryTransactions.restoreRemoval(
                receipt,
                lockedBy: scope
            )
        }
    }

    @discardableResult
    func markPlaybackSucceeded(
        packID: String,
        version: String
    ) throws -> InstalledContentPack {
        try repository.prepareStore()
        return try repository.withStoreLock { scope in
            try playbackHealthTransactions.markSucceeded(
                packID: packID,
                version: version,
                lockedBy: scope
            )
        }
    }

    @discardableResult
    func reportPlaybackFailure(
        packID: String,
        version: String
    ) throws -> InstalledContentPack {
        try repository.prepareStore()
        return try repository.withStoreLock { scope in
            try playbackHealthTransactions.reportFailure(
                packID: packID,
                version: version,
                lockedBy: scope
            )
        }
    }

    /// Removes abandoned staging directories only. Active and immutable version
    /// directories are never considered by this cleanup.
    func recoverInterruptedInstalls(olderThan age: TimeInterval = 3_600) throws -> Int {
        try repository.prepareStore()
        return try repository.withStoreLock { scope in
            try maintenanceTransactions.recoverInterruptedInstalls(
                olderThan: age,
                lockedBy: scope
            )
        }
    }

}
