#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif

enum CompanionContentOperationKind: Equatable {
    case install
    case rollback
    case remove
    case restoreRemoval
    case purgeRecovery
    case exportBackup
    case inspectBackup
    case restoreBackup
}

enum CompanionContentOperationSuccess {
    case installed(
        result: ContentPackInstallResult,
        inventory: [InstalledContentPack]
    )
    case rolledBack(
        pack: InstalledContentPack,
        inventory: [InstalledContentPack]
    )
    case removed(
        inventory: [InstalledContentPack],
        recovery: [ContentPackRecoveryItem]
    )
    case removalRestored(
        pack: InstalledContentPack,
        inventory: [InstalledContentPack],
        recovery: [ContentPackRecoveryItem]
    )
    case recoveryPurged(
        inventory: [InstalledContentPack],
        recovery: [ContentPackRecoveryItem]
    )
    case backupExported(packCount: Int)
    case backupInspected(preview: CompanionBackupPreview)
    case backupRestored(
        settings: CompanionSettingsV1,
        installedPackCount: Int,
        inventory: [InstalledContentPack]
    )
}

struct CompanionContentOperationReceipt {
    let operation: CompanionContentOperationKind
    let success: CompanionContentOperationSuccess?
    let presentedError: String?

    var succeeded: Bool { success != nil && presentedError == nil }
}

struct CompanionContentRecoveryReceipt {
    let cleaned: Int
    let inventory: [InstalledContentPack]
    let recovery: [ContentPackRecoveryItem]
}
