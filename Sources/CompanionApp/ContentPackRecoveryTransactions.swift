import Darwin
import Foundation

/// Synchronous recovery/removal mutations owned exclusively by
/// `ContentPackStore`. Every entry point requires an unforgeable scope issued
/// by the repository's synchronous lock closure, so no recovery mutation can
/// run without the cross-process transaction lock.
struct ContentPackRecoveryTransactions {
    let repository: ContentPackStoreRepository

    func restoreAfterFailedBatch(
        packID: String,
        priorRecord: ActiveContentPackRecord?,
        lockedBy scope: ContentPackStoreLockScope
    ) throws {
        try repository.validateIdentifier(packID)
        if let priorRecord {
            guard priorRecord.packID == packID else {
                throw ContentPackStoreError.invalidPackIdentifier(packID)
            }
            _ = try repository.installedPack(for: priorRecord)
            try repository.writeActiveRecord(priorRecord)
            return
        }
        let source = repository.packDirectory(for: packID)
        guard repository.fileManager.fileExists(atPath: source.path) else { return }
        let destination = repository.removedRoot.appendingPathComponent(
            "batch-rollback-\(UUID().uuidString.lowercased())--\(packID)",
            isDirectory: true
        )
        try repository.fileManager.moveItem(at: source, to: destination)
    }

    func remove(
        packID: String,
        lockedBy scope: ContentPackStoreLockScope
    ) throws -> ContentPackRemovalReceipt {
        try repository.validateIdentifier(packID)
        let source = repository.packDirectory(for: packID)
        guard repository.fileManager.fileExists(atPath: source.path) else {
            throw ContentPackStoreError.noActivePack(packID)
        }
        let destination = repository.removedRoot.appendingPathComponent(
            "\(UUID().uuidString.lowercased())--\(packID)",
            isDirectory: true
        )
        try repository.fileManager.moveItem(at: source, to: destination)
        return ContentPackRemovalReceipt(
            packID: packID,
            quarantinedDirectory: destination
        )
    }

    func inventory(
        lockedBy scope: ContentPackStoreLockScope
    ) throws -> [ContentPackRecoveryItem] {
        try repository.recoveryCatalog.inventory()
    }

    func restoreItem(
        id: String,
        lockedBy scope: ContentPackStoreLockScope
    ) throws -> InstalledContentPack {
        let item = try repository.recoveryCatalog.item(id: id)
        guard item.state == .recoverable, let packID = item.packID else {
            throw ContentPackStoreError.recoveryItemNotRecoverable
        }
        let source = try repository.recoveryCatalog.resolveEntry(id: id)
        return try restoreRemoval(
            ContentPackRemovalReceipt(
                packID: packID,
                quarantinedDirectory: source
            ),
            lockedBy: scope
        )
    }

    func purgeItem(
        id: String,
        lockedBy scope: ContentPackStoreLockScope
    ) throws {
        let target = try repository.recoveryCatalog.resolveEntry(id: id)
        var targetStatus = stat()
        guard lstat(target.path, &targetStatus) == 0 else {
            throw ContentPackStoreError.recoveryItemMissing
        }
        try repository.fileManager.removeItem(at: target)
    }

    func restoreRemoval(
        _ receipt: ContentPackRemovalReceipt,
        lockedBy scope: ContentPackStoreLockScope
    ) throws -> InstalledContentPack {
        try repository.validateIdentifier(receipt.packID)
        let expectedParent = receipt.quarantinedDirectory
            .deletingLastPathComponent()
            .standardizedFileURL
        guard expectedParent == repository.removedRoot.standardizedFileURL else {
            throw ContentPackStoreError.removalReceiptOutsideStore
        }
        let destination = repository.packDirectory(for: receipt.packID)
        guard !repository.fileManager.fileExists(atPath: destination.path) else {
            throw ContentPackStoreError.restoreConflict(receipt.packID)
        }
        guard repository.fileManager.fileExists(
            atPath: receipt.quarantinedDirectory.path
        ) else {
            throw ContentPackStoreError.recoveryItemMissing
        }
        try repository.fileManager.moveItem(
            at: receipt.quarantinedDirectory,
            to: destination
        )
        do {
            guard let record = try repository.readActiveRecord(
                packID: receipt.packID
            ) else {
                throw ContentPackStoreError.noActivePack(receipt.packID)
            }
            return try repository.installedPack(for: record)
        } catch {
            do {
                if repository.fileManager.fileExists(atPath: destination.path),
                   !repository.fileManager.fileExists(
                       atPath: receipt.quarantinedDirectory.path
                   ) {
                    try repository.fileManager.moveItem(
                        at: destination,
                        to: receipt.quarantinedDirectory
                    )
                }
            } catch {
                throw ContentPackStoreError.recoveryRollbackFailed
            }
            throw error
        }
    }
}
