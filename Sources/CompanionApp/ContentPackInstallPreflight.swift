import Foundation

/// Read-only trust and compatibility checks shared by install and batch
/// preflight. The transaction actor owns locking and every filesystem mutation;
/// this component may only inspect a candidate and an already-installed version.
struct ContentPackInstallPreflight {
    let repository: ContentPackStoreRepository
    let signatureVerifier: (any ContentPackSignatureVerifying)?
    let entitlementChecker: (any ContentPackEntitlementChecking)?

    func loadCandidateManifest(
        at packageDirectory: URL
    ) throws -> ContentPackManifest {
        let manifest = try repository.validator.loadAndValidate(
            packageDirectory: packageDirectory,
            currentAppVersion: repository.currentAppVersion
        )
        try repository.validateIdentifier(manifest.id)
        return manifest
    }

    func validateCandidate(
        at packageDirectory: URL,
        expectedManifest: ContentPackManifest? = nil
    ) throws -> ContentPackManifest {
        let manifest = try loadCandidateManifest(at: packageDirectory)
        if let expectedManifest, manifest != expectedManifest {
            throw ContentPackStoreError.versionConflict(
                packID: expectedManifest.id,
                version: expectedManifest.version
            )
        }
        try authorize(manifest, in: packageDirectory)
        return manifest
    }

    func validateVersionTransition(
        manifest: ContentPackManifest,
        candidateDirectory: URL,
        priorRecord: ActiveContentPackRecord?
    ) throws {
        if let priorRecord,
           let currentVersion = SemanticVersion(priorRecord.version),
           let requestedVersion = SemanticVersion(manifest.version),
           requestedVersion < currentVersion {
            throw ContentPackStoreError.downgradeNotAllowed(
                current: priorRecord.version,
                requested: manifest.version
            )
        }

        let destination = repository.versionDirectory(
            packID: manifest.id,
            version: manifest.version
        )
        guard repository.fileManager.fileExists(atPath: destination.path) else {
            return
        }
        let existing = try repository.validator.loadAndValidate(
            packageDirectory: destination,
            currentAppVersion: repository.currentAppVersion
        )
        let candidateHash = try ContentPackValidator.sha256(
            of: candidateDirectory.appendingPathComponent("manifest.json")
        )
        let existingHash = try ContentPackValidator.sha256(
            of: destination.appendingPathComponent("manifest.json")
        )
        guard existing == manifest, existingHash == candidateHash else {
            throw ContentPackStoreError.versionConflict(
                packID: manifest.id,
                version: manifest.version
            )
        }
    }

    func activationRecord(
        manifest: ContentPackManifest,
        priorRecord: ActiveContentPackRecord?
    ) -> ActiveContentPackRecord {
        let sameVersion = priorRecord?.version == manifest.version
        return ActiveContentPackRecord(
            packID: manifest.id,
            version: manifest.version,
            previousVersion: sameVersion
                ? priorRecord?.previousVersion
                : priorRecord?.version,
            health: sameVersion
                ? priorRecord?.health ?? .pendingHealth
                : .pendingHealth
        )
    }

    private func authorize(
        _ manifest: ContentPackManifest,
        in packageDirectory: URL
    ) throws {
        if manifest.tier != .local {
            guard let signatureVerifier else {
                throw ContentPackStoreError.signatureVerifierRequired(manifest.id)
            }
            try signatureVerifier.verifySignature(
                packageDirectory: packageDirectory,
                manifest: manifest
            )
        }
        if manifest.tier == .paid {
            guard let entitlementChecker else {
                throw ContentPackStoreError.entitlementCheckerRequired(manifest.id)
            }
            try entitlementChecker.verifyEntitlement(for: manifest)
        }
    }
}
