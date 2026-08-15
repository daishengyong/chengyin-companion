import Foundation

/// Owns validated `active.json` persistence and projection of one immutable
/// installed version. Directory topology and cross-process locking are injected.
struct ContentPackActiveRecordRepository {
    let layout: ContentPackStoreLayout
    let currentAppVersion: String
    let validator: ContentPackValidator

    func validateIdentifier(_ packID: String) throws {
        guard ContentPackValidator.isValidIdentifier(packID) else {
            throw ContentPackStoreError.invalidPackIdentifier(packID)
        }
    }

    func read(packID: String) throws -> ActiveContentPackRecord? {
        let url = layout.packDirectory(for: packID)
            .appendingPathComponent("active.json")
        guard layout.fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(
            ActiveContentPackRecord.self,
            from: Data(contentsOf: url)
        )
        guard record.schemaVersion == ActiveContentPackRecord.currentSchemaVersion,
              record.packID == packID,
              ContentPackValidator.isValidIdentifier(record.packID),
              SemanticVersion(record.version) != nil,
              record.previousVersion.map({ SemanticVersion($0) != nil }) ?? true
        else {
            throw ContentPackStoreError.invalidPackIdentifier(packID)
        }
        return record
    }

    func write(_ record: ActiveContentPackRecord) throws {
        let packRoot = layout.packDirectory(for: record.packID)
        try layout.createPrivateDirectory(packRoot)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(record)
        let destination = packRoot.appendingPathComponent("active.json")
        try ContentPackAtomicFileWriter.write(data, to: destination)
    }

    func installedPack(
        for record: ActiveContentPackRecord
    ) throws -> InstalledContentPack {
        let directory = layout.versionDirectory(
            packID: record.packID,
            version: record.version
        )
        guard layout.fileManager.fileExists(atPath: directory.path) else {
            throw ContentPackStoreError.rollbackVersionMissing(
                packID: record.packID,
                version: record.version
            )
        }
        let manifest = try validator.loadAndValidate(
            packageDirectory: directory,
            currentAppVersion: currentAppVersion
        )
        guard manifest.id == record.packID, manifest.version == record.version else {
            throw ContentPackStoreError.versionConflict(
                packID: record.packID,
                version: record.version
            )
        }
        return InstalledContentPack(
            record: record,
            manifest: manifest,
            directory: directory
        )
    }
}
