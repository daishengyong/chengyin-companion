import Foundation

enum ContentPackInstallCheckpoint: String, Equatable, Sendable {
    case afterStagingCopy
    case afterStagingValidation
    case afterVersionCommit
    case beforeActivation
    case afterActivation
}

enum ContentPackStoreError: LocalizedError, Equatable, CompanionErrorCoding {
    case invalidPackIdentifier(String)
    case versionConflict(packID: String, version: String)
    case noActivePack(String)
    case noRollbackVersion(String)
    case rollbackVersionMissing(packID: String, version: String)
    case removalReceiptOutsideStore
    case invalidRecoveryItemIdentifier
    case recoveryItemMissing
    case recoveryItemNotRecoverable
    case recoveryRollbackFailed
    case tooManyRecoveryItems
    case restoreConflict(String)
    case downgradeNotAllowed(current: String, requested: String)
    case signatureVerifierRequired(String)
    case entitlementCheckerRequired(String)
    case activeVersionChanged(packID: String, expected: String, actual: String)
    case injectedFailure(ContentPackInstallCheckpoint)

    var companionErrorCode: String {
        switch self {
        case .invalidPackIdentifier: "PACK_STORE_INVALID_IDENTIFIER"
        case .versionConflict: "PACK_STORE_VERSION_CONFLICT"
        case .noActivePack: "PACK_STORE_NO_ACTIVE_PACK"
        case .noRollbackVersion: "PACK_STORE_NO_ROLLBACK_VERSION"
        case .rollbackVersionMissing: "PACK_STORE_ROLLBACK_VERSION_MISSING"
        case .removalReceiptOutsideStore: "PACK_STORE_INVALID_REMOVAL_RECEIPT"
        case .invalidRecoveryItemIdentifier: "PACK_STORE_INVALID_RECOVERY_ITEM"
        case .recoveryItemMissing: "PACK_STORE_RECOVERY_ITEM_MISSING"
        case .recoveryItemNotRecoverable: "PACK_STORE_RECOVERY_ITEM_NOT_RESTORABLE"
        case .recoveryRollbackFailed: "PACK_STORE_RECOVERY_ROLLBACK_FAILED"
        case .tooManyRecoveryItems: "PACK_STORE_RECOVERY_LIMIT_EXCEEDED"
        case .restoreConflict: "PACK_STORE_RESTORE_CONFLICT"
        case .downgradeNotAllowed: "PACK_STORE_DOWNGRADE_REQUIRES_ROLLBACK"
        case .signatureVerifierRequired: "PACK_STORE_SIGNATURE_VERIFIER_REQUIRED"
        case .entitlementCheckerRequired: "PACK_STORE_ENTITLEMENT_CHECKER_REQUIRED"
        case .activeVersionChanged: "PACK_STORE_ACTIVE_VERSION_CHANGED"
        case .injectedFailure: "PACK_STORE_TEST_FAILURE_INJECTED"
        }
    }

    var errorDescription: String? {
        switch self {
        case let .invalidPackIdentifier(identifier):
            return "The content-pack ID is invalid: \(identifier)."
        case let .versionConflict(packID, version):
            return "Content pack \(packID) version \(version) exists with different content."
        case let .noActivePack(packID):
            return "Content pack \(packID) has no active version."
        case let .noRollbackVersion(packID):
            return "Content pack \(packID) has no rollback version."
        case let .rollbackVersionMissing(packID, version):
            return "Content pack \(packID) rollback version \(version) is missing."
        case .removalReceiptOutsideStore:
            return "The removal receipt does not belong to this content library."
        case .invalidRecoveryItemIdentifier:
            return "The recovery item identifier is invalid."
        case .recoveryItemMissing:
            return "The recovery item is no longer available."
        case .recoveryItemNotRecoverable:
            return "The recovery item is damaged or unsafe and cannot be restored."
        case .recoveryRollbackFailed:
            return "The failed recovery could not be returned to the recovery area."
        case .tooManyRecoveryItems:
            return "The recovery area exceeds its bounded item limit."
        case let .restoreConflict(packID):
            return "Content pack \(packID) already exists and cannot be overwritten during recovery."
        case let .downgradeNotAllowed(current, requested):
            return "A normal install cannot downgrade \(current) to \(requested); use explicit rollback."
        case let .signatureVerifierRequired(packID):
            return "Official content pack \(packID) requires a signature verifier."
        case let .entitlementCheckerRequired(packID):
            return "Entitled content pack \(packID) requires an entitlement checker."
        case let .activeVersionChanged(packID, expected, actual):
            return "Content pack \(packID) active version changed from \(expected) to \(actual)."
        case let .injectedFailure(checkpoint):
            return "The test injected an install failure at \(checkpoint.rawValue)."
        }
    }
}

protocol ContentPackSignatureVerifying: Sendable {
    func verifySignature(
        packageDirectory: URL,
        manifest: ContentPackManifest
    ) throws
}

protocol ContentPackEntitlementChecking: Sendable {
    func verifyEntitlement(for manifest: ContentPackManifest) throws
}

enum ContentPackHealthStatus: String, Codable, Equatable, Sendable {
    case pendingHealth
    case healthy
    case disabled
}

/// Derived trust signal; it is never accepted from a pack manifest.
/// A creator cannot self-assert Stable or Verified.
enum ContentPackQualityLevel: String, CaseIterable, Equatable, Sendable {
    case lab
    case stable
    case verified
}

struct ActiveContentPackRecord: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let packID: String
    let version: String
    let previousVersion: String?
    let health: ContentPackHealthStatus
    let activatedAt: Date

    init(
        packID: String,
        version: String,
        previousVersion: String?,
        health: ContentPackHealthStatus = .pendingHealth,
        activatedAt: Date = Date()
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.packID = packID
        self.version = version
        self.previousVersion = previousVersion
        self.health = health
        self.activatedAt = activatedAt
    }
}

struct InstalledContentPack: Equatable, Sendable {
    let record: ActiveContentPackRecord
    let manifest: ContentPackManifest
    let directory: URL

    var qualityLevel: ContentPackQualityLevel {
        guard record.health == .healthy else { return .lab }
        return manifest.tier == .local ? .stable : .verified
    }
}

enum ContentPackInstallDisposition: String, Equatable, Sendable {
    case installed
    case reusedExistingVersion
}

struct ContentPackInstallResult: Equatable, Sendable {
    let pack: InstalledContentPack
    let disposition: ContentPackInstallDisposition
}

/// A coherent read-only projection produced under one repository lock.
struct ContentPackStoreSnapshot: Equatable, Sendable {
    let inventory: [InstalledContentPack]
    let recovery: [ContentPackRecoveryItem]
}

struct ContentPackRemovalReceipt: Equatable, Sendable {
    let packID: String
    let quarantinedDirectory: URL
}
