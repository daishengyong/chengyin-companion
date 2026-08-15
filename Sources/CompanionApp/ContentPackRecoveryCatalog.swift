import Foundation

enum ContentPackRecoveryItemState: String, Equatable, Sendable {
    case recoverable
    case needsCleanup
}

/// Path-free projection of one entry in the private content-pack recovery area.
/// `id` is an opaque, validated basename and is the only value accepted by
/// restore and purge operations; callers never receive a filesystem URL.
struct ContentPackRecoveryItem: Identifiable, Equatable, Sendable {
    let id: String
    let packID: String?
    let version: String?
    let character: String?
    let removedAt: Date?
    let state: ContentPackRecoveryItemState
    let failureCode: String?
}

struct ContentPackRecoveryCatalog {
    static let maximumItems = 128
    static let symlinkEntryCode = "PACK_RECOVERY_SYMLINK_ENTRY"
    static let invalidEntryCode = "PACK_RECOVERY_INVALID_ENTRY"
    static let invalidMetadataCode = "PACK_RECOVERY_INVALID_METADATA"
    static let invalidContentCode = "PACK_RECOVERY_INVALID_CONTENT"

    private static let maximumActiveRecordBytes = 256 * 1_024

    private let removedRoot: URL
    private let currentAppVersion: String
    private let fileManager: FileManager
    private let validator: ContentPackValidator

    init(
        removedRoot: URL,
        currentAppVersion: String,
        fileManager: FileManager = .default
    ) {
        self.removedRoot = removedRoot.standardizedFileURL
        self.currentAppVersion = currentAppVersion
        self.fileManager = fileManager
        validator = ContentPackValidator(fileManager: fileManager)
    }

    func inventory() throws -> [ContentPackRecoveryItem] {
        let entries = try fileManager.contentsOfDirectory(
            at: removedRoot,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .contentModificationDateKey
            ],
            options: [.skipsHiddenFiles]
        )
        guard entries.count <= Self.maximumItems else {
            throw ContentPackStoreError.tooManyRecoveryItems
        }

        return entries.compactMap(item(for:)).sorted { lhs, rhs in
            switch (lhs.removedAt, rhs.removedAt) {
            case let (left?, right?) where left != right:
                return left > right
            default:
                return lhs.id < rhs.id
            }
        }
    }

    func item(id: String) throws -> ContentPackRecoveryItem {
        let entry = try resolveEntry(id: id)
        guard fileManager.fileExists(atPath: entry.path) else {
            throw ContentPackStoreError.recoveryItemMissing
        }
        guard let item = item(for: entry) else {
            throw ContentPackStoreError.recoveryItemNotRecoverable
        }
        return item
    }

    func resolveEntry(id: String) throws -> URL {
        guard Self.isValidOpaqueID(id) else {
            throw ContentPackStoreError.invalidRecoveryItemIdentifier
        }
        let candidate = removedRoot.appendingPathComponent(id, isDirectory: true)
        guard candidate.deletingLastPathComponent().standardizedFileURL == removedRoot,
              candidate.lastPathComponent == id
        else {
            throw ContentPackStoreError.invalidRecoveryItemIdentifier
        }
        return candidate
    }

    static func isValidOpaqueID(_ id: String) -> Bool {
        guard !id.isEmpty,
              id.utf8.count <= 240,
              id != ".",
              id != "..",
              id.unicodeScalars.allSatisfy({ $0.isASCII })
        else {
            return false
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard let first = id.unicodeScalars.first,
              CharacterSet.alphanumerics.contains(first)
        else {
            return false
        }
        return id.unicodeScalars.allSatisfy(allowed.contains)
    }

    private func item(for entry: URL) -> ContentPackRecoveryItem? {
        let id = entry.lastPathComponent
        guard Self.isValidOpaqueID(id) else { return nil }
        let values = try? entry.resourceValues(forKeys: [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey
        ])
        let removedAt = values?.contentModificationDate
        guard values?.isSymbolicLink != true else {
            return invalidItem(id: id, removedAt: removedAt, code: Self.symlinkEntryCode)
        }
        guard values?.isDirectory == true,
              let packID = packID(from: id)
        else {
            return invalidItem(id: id, removedAt: removedAt, code: Self.invalidEntryCode)
        }

        let activeURL = entry.appendingPathComponent("active.json", isDirectory: false)
        guard let activeValues = try? activeURL.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ]),
              activeValues.isRegularFile == true,
              activeValues.isSymbolicLink != true,
              let size = activeValues.fileSize,
              size > 0,
              size <= Self.maximumActiveRecordBytes,
              let data = try? Data(contentsOf: activeURL, options: [.mappedIfSafe])
        else {
            return invalidItem(
                id: id,
                packID: packID,
                removedAt: removedAt,
                code: Self.invalidMetadataCode
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let record = try? decoder.decode(ActiveContentPackRecord.self, from: data),
              record.schemaVersion == ActiveContentPackRecord.currentSchemaVersion,
              record.packID == packID,
              SemanticVersion(record.version) != nil,
              record.previousVersion.map({ SemanticVersion($0) != nil }) ?? true
        else {
            return invalidItem(
                id: id,
                packID: packID,
                removedAt: removedAt,
                code: Self.invalidMetadataCode
            )
        }

        let versionDirectory = entry
            .appendingPathComponent("versions", isDirectory: true)
            .appendingPathComponent(record.version, isDirectory: true)
        guard let manifest = try? validator.loadAndValidate(
            packageDirectory: versionDirectory,
            currentAppVersion: currentAppVersion
        ), manifest.id == packID, manifest.version == record.version else {
            return invalidItem(
                id: id,
                packID: packID,
                version: record.version,
                removedAt: removedAt,
                code: Self.invalidContentCode
            )
        }

        return ContentPackRecoveryItem(
            id: id,
            packID: packID,
            version: record.version,
            character: manifest.character,
            removedAt: removedAt,
            state: .recoverable,
            failureCode: nil
        )
    }

    private func packID(from entryID: String) -> String? {
        guard let delimiter = entryID.range(of: "--", options: .backwards) else {
            return nil
        }
        let packID = String(entryID[delimiter.upperBound...])
        return ContentPackValidator.isValidIdentifier(packID) ? packID : nil
    }

    private func invalidItem(
        id: String,
        packID: String? = nil,
        version: String? = nil,
        removedAt: Date?,
        code: String
    ) -> ContentPackRecoveryItem {
        ContentPackRecoveryItem(
            id: id,
            packID: packID,
            version: version,
            character: nil,
            removedAt: removedAt,
            state: .needsCleanup,
            failureCode: code
        )
    }
}
