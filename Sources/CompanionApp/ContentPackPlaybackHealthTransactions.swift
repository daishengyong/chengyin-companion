import Foundation

/// Synchronous playback-health mutations owned exclusively by
/// `ContentPackStore`. Each transition requires the unforgeable repository
/// lock scope, so a real playback result cannot race another process changing
/// the active record.
struct ContentPackPlaybackHealthTransactions {
    let repository: ContentPackStoreRepository

    func markSucceeded(
        packID: String,
        version: String,
        lockedBy scope: ContentPackStoreLockScope
    ) throws -> InstalledContentPack {
        let current = try activeRecord(packID: packID, expectedVersion: version)
        let healthy = ActiveContentPackRecord(
            packID: current.packID,
            version: current.version,
            previousVersion: current.previousVersion,
            health: .healthy
        )
        try repository.writeActiveRecord(healthy)
        return try repository.installedPack(for: healthy)
    }

    /// Rolls a pending revision back after a real playback failure. A first
    /// install without a previous revision is retained for diagnosis but marked
    /// disabled so the runtime resolver can fall back to bundled Starter media.
    func reportFailure(
        packID: String,
        version: String,
        lockedBy scope: ContentPackStoreLockScope
    ) throws -> InstalledContentPack {
        let current = try activeRecord(packID: packID, expectedVersion: version)
        guard current.health == .pendingHealth else {
            return try repository.installedPack(for: current)
        }

        let replacement: ActiveContentPackRecord
        if let previousVersion = current.previousVersion {
            let previousDirectory = repository.versionDirectory(
                packID: packID,
                version: previousVersion
            )
            guard repository.fileManager.fileExists(atPath: previousDirectory.path) else {
                throw ContentPackStoreError.rollbackVersionMissing(
                    packID: packID,
                    version: previousVersion
                )
            }
            _ = try repository.validator.loadAndValidate(
                packageDirectory: previousDirectory,
                currentAppVersion: repository.currentAppVersion
            )
            replacement = ActiveContentPackRecord(
                packID: packID,
                version: previousVersion,
                previousVersion: nil,
                health: .healthy
            )
        } else {
            replacement = ActiveContentPackRecord(
                packID: packID,
                version: current.version,
                previousVersion: nil,
                health: .disabled
            )
        }
        try repository.writeActiveRecord(replacement)
        return try repository.installedPack(for: replacement)
    }

    private func activeRecord(
        packID: String,
        expectedVersion: String
    ) throws -> ActiveContentPackRecord {
        guard let current = try repository.readActiveRecord(packID: packID) else {
            throw ContentPackStoreError.noActivePack(packID)
        }
        guard current.version == expectedVersion else {
            throw ContentPackStoreError.activeVersionChanged(
                packID: packID,
                expected: expectedVersion,
                actual: current.version
            )
        }
        return current
    }
}
