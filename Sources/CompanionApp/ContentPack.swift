import CryptoKit
import Darwin
import Foundation

#if canImport(CompanionContracts)
import CompanionContracts
#endif



struct ContentPackValidator {
    static let supportedSchemaVersion = 2
    static let maximumFileCount = 256
    static let maximumUnpackedBytes: Int64 = 1_610_612_736
    static let maximumManifestBytes: Int64 = 1_048_576
    static let maximumSingleAssetBytes: Int64 = 536_870_912
    static let maximumMediaPixels = 33_177_600
    static let maximumMediaDurationMs = 600_000
    static let maximumExperienceCount = 64
    static let maximumExperienceStepCount = 8
    static let maximumLocaleCount = 32
    static let maximumAssetCount = 256
    static let maximumFocalKeyframeCount = 32
    static let dynamicProjectionMinimumAppVersion = "0.19.28"

    private static let identifierPattern =
        #"^[a-z0-9]+(?:[.-][a-z0-9]+)+$"#
    private static let experienceIdentifierPattern = #"^[a-z0-9][a-z0-9._-]{0,95}$"#
    private static let compatibilityAssetIdentifierPattern = #"^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$"#
    private static let localePattern = #"^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$"#

    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func loadAndValidate(
        packageDirectory: URL,
        currentAppVersion: String
    ) throws -> ContentPackManifest {
        let manifestURL = packageDirectory.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw ContentPackValidationError.manifestMissing
        }
        let manifestAttributes = try fileManager.attributesOfItem(atPath: manifestURL.path)
        let manifestBytes = (manifestAttributes[.size] as? NSNumber)?.int64Value ?? 0
        guard manifestBytes <= Self.maximumManifestBytes else {
            throw ContentPackValidationError.manifestTooLarge(
                actual: manifestBytes,
                maximum: Self.maximumManifestBytes
            )
        }

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest: ContentPackManifest
        do {
            try ContentPackManifestFieldValidator.validate(manifestData)
            manifest = try JSONDecoder().decode(
                ContentPackManifest.self,
                from: manifestData
            )
        } catch let validationError as ContentPackValidationError {
            throw validationError
        } catch {
            throw ContentPackValidationError.manifestInvalidJSON
        }
        try validate(
            manifest,
            packageDirectory: packageDirectory,
            currentAppVersion: currentAppVersion
        )
        return manifest
    }

    func validate(
        _ manifest: ContentPackManifest,
        packageDirectory: URL,
        currentAppVersion: String
    ) throws {
        guard (1...Self.supportedSchemaVersion).contains(manifest.schemaVersion) else {
            throw ContentPackValidationError.unsupportedSchema(manifest.schemaVersion)
        }
        guard Self.isValidIdentifier(manifest.id) else {
            throw ContentPackValidationError.invalidIdentifier(manifest.id)
        }
        guard let packVersion = SemanticVersion(manifest.version) else {
            throw ContentPackValidationError.invalidSemanticVersion(manifest.version)
        }
        guard let minimumVersion = SemanticVersion(manifest.minAppVersion) else {
            throw ContentPackValidationError.invalidSemanticVersion(manifest.minAppVersion)
        }
        guard let appVersion = SemanticVersion(currentAppVersion) else {
            throw ContentPackValidationError.invalidSemanticVersion(currentAppVersion)
        }
        _ = packVersion
        guard appVersion >= minimumVersion else {
            throw ContentPackValidationError.appVersionTooOld(
                required: manifest.minAppVersion,
                current: currentAppVersion
            )
        }
        guard !manifest.character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContentPackValidationError.emptyCharacter
        }
        guard !manifest.locales.isEmpty else {
            throw ContentPackValidationError.emptyLocales
        }
        guard manifest.locales.count <= Self.maximumLocaleCount else {
            throw ContentPackValidationError.tooManyLocales(
                actual: manifest.locales.count,
                maximum: Self.maximumLocaleCount
            )
        }
        var declaredLocales = Set<String>()
        for locale in manifest.locales {
            guard Self.matches(locale, pattern: Self.localePattern) else {
                throw ContentPackValidationError.invalidLocale(locale)
            }
            guard declaredLocales.insert(locale).inserted else {
                throw ContentPackValidationError.duplicateLocale(locale)
            }
        }
        guard !manifest.license.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContentPackValidationError.emptyLicense
        }

        let root = packageDirectory.standardizedFileURL.resolvingSymlinksInPath()

        guard manifest.assets.count <= Self.maximumAssetCount else {
            throw ContentPackValidationError.tooManyAssets(
                actual: manifest.assets.count,
                maximum: Self.maximumAssetCount
            )
        }
        var assetIDs = Set<String>()
        var assetPaths = Set<String>()
        let contentIdentifierPattern = manifest.contributionMode == .strictV2
            ? Self.experienceIdentifierPattern
            : Self.compatibilityAssetIdentifierPattern
        let assetValidator = ContentPackAssetValidator(fileManager: fileManager)
        for asset in manifest.assets {
            guard Self.matches(
                asset.id,
                pattern: contentIdentifierPattern
            ) else {
                throw ContentPackValidationError.invalidAssetIdentifier(asset.id)
            }
            guard assetIDs.insert(asset.id).inserted else {
                throw ContentPackValidationError.duplicateAssetID(asset.id)
            }
            let foldedPath = asset.path.precomposedStringWithCanonicalMapping
                .lowercased()
            guard assetPaths.insert(foldedPath).inserted else {
                throw ContentPackValidationError.duplicateAssetPath(asset.path)
            }
            if manifest.schemaVersion == 1,
               asset.focalTracks != nil || asset.safeAreas != nil {
                throw ContentPackValidationError.v2FeaturesRequireSchema2
            }
            if asset.focalTracks != nil || asset.safeAreas != nil,
               let required = SemanticVersion(Self.dynamicProjectionMinimumAppVersion),
               minimumVersion < required {
                throw ContentPackValidationError.projectionFeatureRequiresAppVersion(
                    asset: asset.id,
                    required: Self.dynamicProjectionMinimumAppVersion
                )
            }
            try assetValidator.validate(asset, packageRoot: root)
        }
        try validateExperiences(
            manifest.experiences ?? [],
            schemaVersion: manifest.schemaVersion,
            contributionMode: manifest.contributionMode,
            assetsByID: Dictionary(uniqueKeysWithValues: manifest.assets.map { ($0.id, $0) }),
            declaredLocales: declaredLocales
        )
        let declaredTriggers = manifest.assets.flatMap(\.triggers)
            + (manifest.experiences ?? []).flatMap(\.triggers)
        try ContentPackTriggerContract.validateCompatibility(
            triggers: declaredTriggers,
            minimumVersion: minimumVersion
        )
        try ContentPackContributionValidator().validate(
            manifest.contribution,
            schemaVersion: manifest.schemaVersion,
            assetsByID: Dictionary(uniqueKeysWithValues: manifest.assets.map { ($0.id, $0) }),
            declaredLocales: declaredLocales
        )
        try assetValidator.validatePackageContents(
            root,
            declaredPaths: Set(manifest.assets.map(\.path))
        )
    }

    private func validateExperiences(
        _ experiences: [ContentPackExperience],
        schemaVersion: Int,
        contributionMode: ContentPackContributionMode,
        assetsByID: [String: ContentPackAsset],
        declaredLocales: Set<String>
    ) throws {
        if schemaVersion == 1, !experiences.isEmpty {
            throw ContentPackValidationError.v2FeaturesRequireSchema2
        }
        guard experiences.count <= Self.maximumExperienceCount else {
            throw ContentPackValidationError.tooManyExperiences(
                actual: experiences.count,
                maximum: Self.maximumExperienceCount
            )
        }

        var experienceIDs = Set<String>()
        let experienceIdentifierPattern = contributionMode == .strictV2
            ? Self.experienceIdentifierPattern
            : Self.compatibilityAssetIdentifierPattern
        for experience in experiences {
            guard Self.matches(
                experience.id,
                pattern: experienceIdentifierPattern
            ) else {
                throw ContentPackValidationError.invalidExperienceIdentifier(
                    experience.id
                )
            }
            guard experienceIDs.insert(experience.id).inserted else {
                throw ContentPackValidationError.duplicateExperienceID(experience.id)
            }
            guard !experience.steps.isEmpty else {
                throw ContentPackValidationError.emptyExperienceSteps(experience.id)
            }
            guard experience.steps.count <= Self.maximumExperienceStepCount else {
                throw ContentPackValidationError.tooManyExperienceSteps(
                    experience: experience.id,
                    actual: experience.steps.count,
                    maximum: Self.maximumExperienceStepCount
                )
            }
            if let weight = experience.weight,
               !weight.isFinite || !(0.01...100).contains(weight) {
                throw ContentPackValidationError.invalidExperienceWeight(experience.id)
            }
            if let cooldown = experience.cooldownSeconds,
               !(0...(7 * 24 * 60 * 60)).contains(cooldown) {
                throw ContentPackValidationError.invalidExperienceCooldown(experience.id)
            }
            if let locales = experience.locales {
                guard !locales.isEmpty else {
                    throw ContentPackValidationError.emptyExperienceLocales(experience.id)
                }
                var experienceLocales = Set<String>()
                for locale in locales {
                    guard Self.matches(locale, pattern: Self.localePattern),
                          declaredLocales.contains(locale),
                          experienceLocales.insert(locale).inserted else {
                        throw ContentPackValidationError.invalidExperienceLocale(
                            experience: experience.id,
                            locale: locale
                        )
                    }
                }
            }
            for trigger in experience.triggers where !ContentPackTriggerContract.isAllowed(trigger) {
                throw ContentPackValidationError.unsupportedTrigger(trigger)
            }
            for step in experience.steps {
                guard let asset = assetsByID[step.assetID] else {
                    throw ContentPackValidationError.unknownExperienceAsset(
                        experience: experience.id,
                        asset: step.assetID
                    )
                }
                guard asset.kind == .video else {
                    throw ContentPackValidationError.nonVideoExperienceAsset(
                        experience: experience.id,
                        asset: step.assetID
                    )
                }
                if let duration = step.minimumPlaybackMs,
                   !(0...60_000).contains(duration) {
                    throw ContentPackValidationError.invalidExperiencePlaybackDuration(
                        experience: experience.id,
                        asset: step.assetID
                    )
                }
            }
        }
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func isValidIdentifier(_ identifier: String) -> Bool {
        matches(identifier, pattern: identifierPattern)
    }

    private static func matches(_ string: String, pattern: String) -> Bool {
        string.range(of: pattern, options: .regularExpression) != nil
    }

}
