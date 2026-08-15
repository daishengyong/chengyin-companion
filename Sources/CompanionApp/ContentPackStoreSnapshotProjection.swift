import Foundation

/// Produces one read-only view of active and recoverable content while the
/// repository's cross-process lock is held. It owns no lock and performs no
/// mutation; `ContentPackStore` remains the only actor entry point.
struct ContentPackStoreSnapshotProjection {
    let repository: ContentPackStoreRepository
    let recoveryTransactions: ContentPackRecoveryTransactions

    func inventory(
        lockedBy scope: ContentPackStoreLockScope
    ) throws -> [InstalledContentPack] {
        let directories = try repository.fileManager.contentsOfDirectory(
            at: repository.packsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return try directories.compactMap { directory in
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true,
                  let record = try repository.readActiveRecord(
                      packID: directory.lastPathComponent
                  )
            else {
                return nil
            }
            return try repository.installedPack(for: record)
        }
        .sorted { $0.record.packID < $1.record.packID }
    }

    func snapshot(
        lockedBy scope: ContentPackStoreLockScope
    ) throws -> ContentPackStoreSnapshot {
        ContentPackStoreSnapshot(
            inventory: try inventory(lockedBy: scope),
            recovery: try recoveryTransactions.inventory(lockedBy: scope)
        )
    }
}
