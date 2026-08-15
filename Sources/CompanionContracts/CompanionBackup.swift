import Foundation

public struct CompanionBackupPackReference: Codable, Equatable, Sendable {
    public var packID: String
    public var version: String
    public var relativePath: String
    public var manifestSHA256: String

    public init(
        packID: String,
        version: String,
        relativePath: String,
        manifestSHA256: String
    ) {
        self.packID = packID
        self.version = version
        self.relativePath = relativePath
        self.manifestSHA256 = manifestSHA256
    }
}

public struct CompanionBackupManifestV1: Codable, Equatable, Sendable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var createdAt: Date
    public var appVersion: String
    public var settings: CompanionSettingsV1
    public var packs: [CompanionBackupPackReference]

    public init(
        schemaVersion: Int = CompanionBackupManifestV1.schemaVersion,
        createdAt: Date = Date(),
        appVersion: String,
        settings: CompanionSettingsV1,
        packs: [CompanionBackupPackReference]
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.settings = settings
        self.packs = packs
    }
}

public enum CompanionBackupValidationError: Error, Equatable, Sendable {
    case payloadTooLarge
    case malformedPayload
    case unsupportedSchema
    case unsupportedSettingsSchema
    case invalidAppVersion
    case tooManyPacks
    case duplicatePackID
    case invalidPackIdentifier
    case invalidPackVersion
    case invalidRelativePath
    case invalidManifestHash
    case invalidDisplayTarget

    public var companionErrorCode: String {
        switch self {
        case .payloadTooLarge: "BACKUP_VALIDATION_PAYLOAD_TOO_LARGE"
        case .malformedPayload: "BACKUP_VALIDATION_MALFORMED_PAYLOAD"
        case .unsupportedSchema: "BACKUP_VALIDATION_UNSUPPORTED_SCHEMA"
        case .unsupportedSettingsSchema: "BACKUP_VALIDATION_UNSUPPORTED_SETTINGS_SCHEMA"
        case .invalidAppVersion: "BACKUP_VALIDATION_INVALID_APP_VERSION"
        case .tooManyPacks: "BACKUP_VALIDATION_TOO_MANY_PACKS"
        case .duplicatePackID: "BACKUP_VALIDATION_DUPLICATE_PACK_ID"
        case .invalidPackIdentifier: "BACKUP_VALIDATION_INVALID_PACK_ID"
        case .invalidPackVersion: "BACKUP_VALIDATION_INVALID_PACK_VERSION"
        case .invalidRelativePath: "BACKUP_VALIDATION_INVALID_RELATIVE_PATH"
        case .invalidManifestHash: "BACKUP_VALIDATION_INVALID_MANIFEST_HASH"
        case .invalidDisplayTarget: "BACKUP_VALIDATION_INVALID_DISPLAY_TARGET"
        }
    }
}

extension CompanionBackupValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .payloadTooLarge:
            "The backup manifest exceeds 1 MiB."
        case .malformedPayload:
            "The backup manifest is not valid backup JSON."
        case .unsupportedSchema:
            "The backup manifest schema is not supported."
        case .unsupportedSettingsSchema:
            "The settings schema in the backup is not supported."
        case .invalidAppVersion:
            "The backup app version is invalid."
        case .tooManyPacks:
            "The backup references too many content packs."
        case .duplicatePackID:
            "The backup contains a duplicate content pack ID."
        case .invalidPackIdentifier:
            "A content pack ID in the backup is invalid."
        case .invalidPackVersion:
            "A content pack version in the backup is invalid."
        case .invalidRelativePath:
            "A content pack backup path is invalid."
        case .invalidManifestHash:
            "A content pack manifest hash is invalid."
        case .invalidDisplayTarget:
            "The preferred display target is invalid."
        }
    }
}

public enum CompanionBackupCodec {
    public static let maximumPayloadBytes = 1_048_576
    public static let maximumPackCount = 256

    public static func encode(_ manifest: CompanionBackupManifestV1) throws -> Data {
        try validate(manifest)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        guard data.count <= maximumPayloadBytes else {
            throw CompanionBackupValidationError.payloadTooLarge
        }
        return data
    }

    public static func decode(_ data: Data) throws -> CompanionBackupManifestV1 {
        guard data.count <= maximumPayloadBytes else {
            throw CompanionBackupValidationError.payloadTooLarge
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest: CompanionBackupManifestV1
        do {
            manifest = try decoder.decode(CompanionBackupManifestV1.self, from: data)
        } catch let error as CompanionBackupValidationError {
            throw error
        } catch {
            throw CompanionBackupValidationError.malformedPayload
        }
        try validate(manifest)
        return manifest
    }

    public static func validate(_ manifest: CompanionBackupManifestV1) throws {
        guard manifest.schemaVersion == CompanionBackupManifestV1.schemaVersion else {
            throw CompanionBackupValidationError.unsupportedSchema
        }
        guard manifest.settings.schemaVersion == CompanionSettingsV1.schemaVersion else {
            throw CompanionBackupValidationError.unsupportedSettingsSchema
        }
        guard manifest.settings.displayTarget.isValid else {
            throw CompanionBackupValidationError.invalidDisplayTarget
        }
        guard !manifest.appVersion.isEmpty, manifest.appVersion.count <= 64 else {
            throw CompanionBackupValidationError.invalidAppVersion
        }
        guard manifest.packs.count <= maximumPackCount else {
            throw CompanionBackupValidationError.tooManyPacks
        }

        var packIDs = Set<String>()
        for pack in manifest.packs {
            guard packIDs.insert(pack.packID).inserted else {
                throw CompanionBackupValidationError.duplicatePackID
            }
            guard matches(pack.packID, #"^[a-z0-9]+(?:[.-][a-z0-9]+)+$"#) else {
                throw CompanionBackupValidationError.invalidPackIdentifier
            }
            guard matches(
                pack.version,
                #"^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"#
            ) else {
                throw CompanionBackupValidationError.invalidPackVersion
            }
            let path = pack.relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = NSString(string: path).pathComponents
            guard path.hasPrefix("packs/"),
                  !path.hasPrefix("/"),
                  !path.contains("\\"),
                  !components.contains("."),
                  !components.contains(".."),
                  components.count == 3,
                  components[1] == pack.packID,
                  components[2] == pack.version else {
                throw CompanionBackupValidationError.invalidRelativePath
            }
            guard matches(pack.manifestSHA256, #"^[a-f0-9]{64}$"#) else {
                throw CompanionBackupValidationError.invalidManifestHash
            }
        }
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}
