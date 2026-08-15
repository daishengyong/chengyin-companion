import Foundation

/// Synchronous version rollback and abandoned-staging maintenance. Every entry
/// requires the repository's unforgeable lock scope; active versions and
/// staging directories therefore cannot be changed outside the store lock.
struct ContentPackStoreMaintenanceTransactions {
    let repository: ContentPackStoreRepository

    func rollback(
        packID: String,
        lockedBy scope: ContentPackStoreLockScope
    ) throws -> InstalledContentPack {
        try repository.validateIdentifier(packID)
        guard let current = try repository.readActiveRecord(packID: packID) else {
            throw ContentPackStoreError.noActivePack(packID)
        }
        guard let previousVersion = current.previousVersion else {
            throw ContentPackStoreError.noRollbackVersion(packID)
        }

        let target = repository.versionDirectory(
            packID: packID,
            version: previousVersion
        )
        guard repository.fileManager.fileExists(atPath: target.path) else {
            throw ContentPackStoreError.rollbackVersionMissing(
                packID: packID,
                version: previousVersion
            )
        }
        _ = try repository.validator.loadAndValidate(
            packageDirectory: target,
            currentAppVersion: repository.currentAppVersion
        )
        let record = ActiveContentPackRecord(
            packID: packID,
            version: previousVersion,
            previousVersion: current.version,
            health: .healthy
        )
        try repository.writeActiveRecord(record)
        return try repository.installedPack(for: record)
    }

    /// Removes only verified, direct-child staging directories with the exact
    /// `.staging` suffix. Active and immutable version directories are outside
    /// this component's reachable root.
    func recoverInterruptedInstalls(
        olderThan age: TimeInterval,
        now: Date = Date(),
        lockedBy scope: ContentPackStoreLockScope
    ) throws -> Int {
        let cutoff = now.addingTimeInterval(-max(0, age))
        let candidates = try repository.fileManager.contentsOfDirectory(
            at: repository.stagingRoot,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .contentModificationDateKey,
            ],
            options: [.skipsHiddenFiles]
        )
        var removed = 0
        for candidate in candidates
            where candidate.lastPathComponent.hasSuffix(".staging") {
            let values = try candidate.resourceValues(
                forKeys: [.isDirectoryKey, .contentModificationDateKey]
            )
            guard values.isDirectory == true,
                  (values.contentModificationDate ?? .distantPast) <= cutoff
            else {
                continue
            }
            try repository.fileManager.removeItem(at: candidate)
            removed += 1
        }
        return removed
    }
}
