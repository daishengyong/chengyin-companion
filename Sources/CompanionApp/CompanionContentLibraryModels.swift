import Foundation

typealias CompanionContentInstallSnapshot = (
    result: ContentPackInstallResult,
    inventory: [InstalledContentPack]
)

typealias CompanionContentPackSnapshot = (
    pack: InstalledContentPack,
    inventory: [InstalledContentPack]
)

typealias CompanionContentRemovalSnapshot = (
    receipt: ContentPackRemovalReceipt,
    inventory: [InstalledContentPack],
    recovery: [ContentPackRecoveryItem]
)

typealias CompanionContentRestoreSnapshot = (
    pack: InstalledContentPack,
    inventory: [InstalledContentPack],
    recovery: [ContentPackRecoveryItem]
)

typealias CompanionContentRecoverySnapshot = (
    inventory: [InstalledContentPack],
    recovery: [ContentPackRecoveryItem]
)

typealias CompanionContentBackupRestoreSnapshot = (
    result: CompanionBackupRestoreResult,
    inventory: [InstalledContentPack]
)

typealias CompanionContentMaintenanceSnapshot = (
    cleaned: Int,
    inventory: [InstalledContentPack],
    recovery: [ContentPackRecoveryItem]
)
