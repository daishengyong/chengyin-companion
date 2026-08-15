import Foundation

/// Synchronous staging and activation mutations for one validated install.
/// Every filesystem entry point requires the repository's unforgeable lock
/// scope; media decoding therefore remains outside this component.
struct ContentPackInstallTransactions {
    let repository: ContentPackStoreRepository
    let preflight: ContentPackInstallPreflight

    func stage(
        packageDirectory: URL,
        failAt checkpoint: ContentPackInstallCheckpoint?,
        lockedBy scope: ContentPackStoreLockScope
    ) throws -> URL {
        let stagingDirectory = repository.stagingRoot.appendingPathComponent(
            "\(UUID().uuidString.lowercased()).staging",
            isDirectory: true
        )
        do {
            try repository.fileManager.copyItem(
                at: packageDirectory,
                to: stagingDirectory
            )
            try inject(checkpoint, at: .afterStagingCopy)
            return stagingDirectory
        } catch {
            try? discardOwnedStaging(stagingDirectory)
            throw error
        }
    }

    func commit(
        stagingDirectory: URL,
        expectedManifest: ContentPackManifest,
        failAt checkpoint: ContentPackInstallCheckpoint?,
        lockedBy scope: ContentPackStoreLockScope
    ) throws -> ContentPackInstallResult {
        var committedVersionDirectory: URL?
        var activationCompleted = false

        do {
            let manifest = try preflight.validateCandidate(
                at: stagingDirectory,
                expectedManifest: expectedManifest
            )
            let versionsRoot = repository.packDirectory(for: manifest.id)
                .appendingPathComponent("versions", isDirectory: true)
            try repository.createPrivateDirectory(versionsRoot)
            let prior = try repository.readActiveRecord(packID: manifest.id)
            let destination = versionsRoot.appendingPathComponent(
                manifest.version,
                isDirectory: true
            )
            try preflight.validateVersionTransition(
                manifest: manifest,
                candidateDirectory: stagingDirectory,
                priorRecord: prior
            )

            let disposition: ContentPackInstallDisposition
            if repository.fileManager.fileExists(atPath: destination.path) {
                try discardOwnedStaging(stagingDirectory)
                disposition = .reusedExistingVersion
            } else {
                try repository.fileManager.moveItem(
                    at: stagingDirectory,
                    to: destination
                )
                committedVersionDirectory = destination
                disposition = .installed
            }

            try inject(checkpoint, at: .afterVersionCommit)
            try inject(checkpoint, at: .beforeActivation)

            let record = preflight.activationRecord(
                manifest: manifest,
                priorRecord: prior
            )
            try repository.writeActiveRecord(record)
            activationCompleted = true
            try inject(checkpoint, at: .afterActivation)

            return ContentPackInstallResult(
                pack: InstalledContentPack(
                    record: record,
                    manifest: manifest,
                    directory: destination
                ),
                disposition: disposition
            )
        } catch {
            try? discardOwnedStaging(stagingDirectory)
            if !activationCompleted,
               let committedVersionDirectory,
               repository.fileManager.fileExists(
                   atPath: committedVersionDirectory.path
               ) {
                try? repository.fileManager.removeItem(
                    at: committedVersionDirectory
                )
            }
            throw error
        }
    }

    func discard(
        stagingDirectory: URL,
        lockedBy scope: ContentPackStoreLockScope
    ) throws {
        try discardOwnedStaging(stagingDirectory)
    }

    func inject(
        _ requested: ContentPackInstallCheckpoint?,
        at checkpoint: ContentPackInstallCheckpoint
    ) throws {
        if requested == checkpoint {
            throw ContentPackStoreError.injectedFailure(checkpoint)
        }
    }

    private func discardOwnedStaging(_ candidate: URL) throws {
        let normalized = candidate.standardizedFileURL
        guard normalized.deletingLastPathComponent()
            == repository.stagingRoot.standardizedFileURL,
              normalized.lastPathComponent.hasSuffix(".staging")
        else {
            return
        }
        if repository.fileManager.fileExists(atPath: normalized.path) {
            try repository.fileManager.removeItem(at: normalized)
        }
    }
}
