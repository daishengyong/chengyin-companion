#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Foundation

enum CompanionBackupServiceError: LocalizedError, Equatable, CompanionErrorCoding {
    case destinationAlreadyExists
    case backupManifestMissing
    case packPayloadMissing(String)
    case packManifestHashMismatch(String)
    case restoreRollbackFailed(String)

    var companionErrorCode: String {
        switch self {
        case .destinationAlreadyExists: "BACKUP_SERVICE_DESTINATION_EXISTS"
        case .backupManifestMissing: "BACKUP_SERVICE_MANIFEST_MISSING"
        case .packPayloadMissing: "BACKUP_SERVICE_PACK_PAYLOAD_MISSING"
        case .packManifestHashMismatch: "BACKUP_SERVICE_PACK_HASH_MISMATCH"
        case .restoreRollbackFailed: "BACKUP_SERVICE_ROLLBACK_FAILED"
        }
    }

    var errorDescription: String? {
        switch self {
        case .destinationAlreadyExists:
            return "The backup destination already exists; choose a new folder."
        case .backupManifestMissing:
            return "The backup is missing backup.json."
        case let .packPayloadMissing(packID):
            return "The backup is missing files for content pack \(packID)."
        case let .packManifestHashMismatch(packID):
            return "Content pack \(packID) in the backup has a manifest hash mismatch."
        case let .restoreRollbackFailed(detail):
            return "Backup restore failed and automatic rollback needs inspection: \(detail)"
        }
    }
}

struct CompanionBackupRestoreResult: Sendable {
    let settings: CompanionSettingsV1
    let installedPacks: [InstalledContentPack]
}

/// Exports only explicit settings and active pack revisions. It never exports
/// Codex sessions, prompts, task titles, paths, event spool files or telemetry.
actor CompanionBackupService {
    private let packStore: ContentPackStore
    private let appVersion: String
    private let fileManager: FileManager

    init(
        packStore: ContentPackStore,
        appVersion: String,
        fileManager: FileManager = .default
    ) {
        self.packStore = packStore
        self.appVersion = appVersion
        self.fileManager = fileManager
    }

    func export(
        to destination: URL,
        settings: CompanionSettingsV1
    ) async throws -> CompanionBackupManifestV1 {
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw CompanionBackupServiceError.destinationAlreadyExists
        }
        let parent = destination.deletingLastPathComponent()
        let staging = parent.appendingPathComponent(
            ".\(destination.lastPathComponent).\(UUID().uuidString).staging",
            isDirectory: true
        )

        do {
            try createPrivateDirectory(staging)
            let inventory = try await packStore.inventory()
            var references: [CompanionBackupPackReference] = []
            for pack in inventory where pack.record.health != .disabled {
                let relativePath = "packs/\(pack.record.packID)/\(pack.record.version)"
                let target = staging.appendingPathComponent(
                    relativePath,
                    isDirectory: true
                )
                try fileManager.createDirectory(
                    at: target.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fileManager.copyItem(at: pack.directory, to: target)
                let manifestHash = try ContentPackValidator.sha256(
                    of: target.appendingPathComponent("manifest.json")
                )
                references.append(
                    CompanionBackupPackReference(
                        packID: pack.record.packID,
                        version: pack.record.version,
                        relativePath: relativePath,
                        manifestSHA256: manifestHash
                    )
                )
            }

            let manifest = CompanionBackupManifestV1(
                appVersion: appVersion,
                settings: settings,
                packs: references
            )
            let data = try CompanionBackupCodec.encode(manifest)
            let manifestURL = staging.appendingPathComponent("backup.json")
            try data.write(to: manifestURL, options: [.atomic])
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: manifestURL.path
            )
            try fileManager.moveItem(at: staging, to: destination)
            return manifest
        } catch {
            if fileManager.fileExists(atPath: staging.path) {
                try? fileManager.removeItem(at: staging)
            }
            throw error
        }
    }

    func inspect(at backupDirectory: URL) throws -> CompanionBackupManifestV1 {
        let manifestURL = backupDirectory.appendingPathComponent("backup.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw CompanionBackupServiceError.backupManifestMissing
        }
        return try CompanionBackupCodec.decode(Data(contentsOf: manifestURL))
    }

    /// Returns restored settings to the caller instead of silently applying
    /// them. UI must show the user the scope before committing preferences.
    func restore(from backupDirectory: URL) async throws -> CompanionBackupRestoreResult {
        let manifest = try inspect(at: backupDirectory)
        var candidates: [(reference: CompanionBackupPackReference, directory: URL)] = []
        for reference in manifest.packs {
            let packageDirectory = backupDirectory.appendingPathComponent(
                reference.relativePath,
                isDirectory: true
            )
            guard fileManager.fileExists(atPath: packageDirectory.path) else {
                throw CompanionBackupServiceError.packPayloadMissing(reference.packID)
            }
            let actualHash = try ContentPackValidator.sha256(
                of: packageDirectory.appendingPathComponent("manifest.json")
            )
            guard actualHash == reference.manifestSHA256 else {
                throw CompanionBackupServiceError.packManifestHashMismatch(reference.packID)
            }
            let candidate = try await packStore.preflightInstall(from: packageDirectory)
            guard candidate.id == reference.packID,
                  candidate.version == reference.version else {
                throw CompanionBackupServiceError.packManifestHashMismatch(reference.packID)
            }
            candidates.append((reference, packageDirectory))
        }

        let priorInventory = try await packStore.inventory()
        let priorRecords = Dictionary(
            uniqueKeysWithValues: priorInventory.map {
                ($0.record.packID, $0.record)
            }
        )
        var installed: [InstalledContentPack] = []
        var changedPackIDs: [String] = []
        do {
            for candidate in candidates {
                let result = try await packStore.install(from: candidate.directory)
                installed.append(result.pack)
                changedPackIDs.append(candidate.reference.packID)
            }
        } catch {
            var rollbackFailures: [String] = []
            for packID in changedPackIDs.reversed() {
                do {
                    try await packStore.restoreAfterFailedBatch(
                        packID: packID,
                        priorRecord: priorRecords[packID]
                    )
                } catch {
                    rollbackFailures.append("\(packID): \(error.localizedDescription)")
                }
            }
            if !rollbackFailures.isEmpty {
                throw CompanionBackupServiceError.restoreRollbackFailed(
                    rollbackFailures.joined(separator: "; ")
                )
            }
            throw error
        }
        return CompanionBackupRestoreResult(
            settings: manifest.settings,
            installedPacks: installed
        )
    }

    private func createPrivateDirectory(_ directory: URL) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
    }
}
