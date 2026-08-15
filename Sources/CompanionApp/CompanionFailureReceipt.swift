import Foundation

/// Stable, language-neutral failure identity used by creator tools, UI support
/// receipts and issue deduplication. Codes are API: rename only in a breaking
/// compatibility release.
protocol CompanionErrorCoding: Error {
    var companionErrorCode: String { get }
}

func companionErrorCode(
    for error: Error,
    fallback: String = "COMPANION_UNEXPECTED_ERROR"
) -> String {
    (error as? any CompanionErrorCoding)?.companionErrorCode ?? fallback
}

/// Public receipts and support logs must never echo contributor machine paths.
/// Detailed system errors stay local to the debugger; creator-facing output is
/// deterministic and safe to paste into an issue.
func companionSafeFailureMessage(for error: Error) -> String {
    let raw = (error as? LocalizedError)?.errorDescription
        ?? error.localizedDescription
    let patterns = [
        #"file://[^\s\]\[()]+"#,
        #"(?<![A-Za-z0-9])/(?:[^\s\]\[():]+/)*[^\s\]\[():]*"#,
        #"[A-Za-z]:\\(?:[^\s\]\[():]+\\)*[^\s\]\[():]*"#
    ]
    return patterns.reduce(raw) { value, pattern in
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return value
        }
        let range = NSRange(value.startIndex..., in: value)
        return expression.stringByReplacingMatches(
            in: value,
            range: range,
            withTemplate: "<redacted-path>"
        )
    }
}

/// Stable, executable next steps shared by validator and audit receipts. The
/// app localizes equivalent wording while preserving the same error identity.
func companionRecoveryAction(for code: String) -> String {
    switch code {
    case let value where value.hasPrefix("PACK_ARCHIVE_"):
        return "Discard the archive, rebuild it with scripts/build-content-pack-archive.sh, then rerun scripts/audit-content-pack-archive.sh <archive.chengyinpack> --json."
    case "PACK_VALIDATION_UNKNOWN_MANIFEST_FIELD":
        return "Remove the unknown manifest key, then rerun scripts/validate-content-pack.sh <pack-directory> --json."
    case "PACK_VALIDATION_PRIVATE_PATH_DISCLOSURE":
        return "Replace local paths with an opaque evidence ID or public source description, then rerun validation."
    case "PACK_VALIDATION_SYMBOLIC_LINK", "PACK_VALIDATION_HARD_LINK",
         "PACK_VALIDATION_PATH_TRAVERSAL", "PACK_VALIDATION_INVALID_ASSET_PATH":
        return "Copy the asset into the pack as a regular file, update its relative path and SHA-256, then rerun validation."
    case "PACK_VALIDATION_ASSET_TOO_LARGE", "PACK_VALIDATION_MEDIA_DIMENSIONS_TOO_LARGE",
         "PACK_VALIDATION_MEDIA_DURATION_TOO_LONG", "PACK_VALIDATION_UNPACKED_SIZE_TOO_LARGE":
        return "Transcode or split the media below the documented limits, update metadata and SHA-256, then rerun validation."
    case let value where value.hasPrefix("PACK_MEDIA_"):
        return "Replace or transcode the failing asset, update its declared metadata and SHA-256, then rerun scripts/validate-content-pack.sh <pack-directory> --json."
    case let value where value.contains("RIGHTS")
        || value.contains("CONTRIBUTION")
        || value.contains("ACCESSIBILITY")
        || value.contains("FALLBACK"):
        return "Run scripts/audit-content-pack.sh <pack-directory> --strict --json, complete the reported v2 evidence, then validate again."
    case let value where value.hasPrefix("PACK_VALIDATION_"):
        return "Correct manifest.json or the declared assets, then rerun scripts/validate-content-pack.sh <pack-directory> --json."
    case let value where value.hasPrefix("CREATOR_AUDIT_"):
        return "Correct the command options or pack directory, then rerun scripts/audit-content-pack.sh <pack-directory> --strict --json."
    case let value where value.hasPrefix("CREATOR_CLI_"):
        return "Correct the command options or pack directory, then rerun scripts/validate-content-pack.sh <pack-directory> --json."
    case let value where value.hasPrefix("CREATOR_MIGRATION_"):
        return "Correct the command options or pack directory, then rerun scripts/plan-content-pack-v2-migration.sh <pack-directory> --json."
    case let value where value.hasPrefix("CREATOR_LOCALE_MATRIX_"):
        return "Correct the command options or pack directory, then rerun scripts/audit-content-pack-locales.sh <pack-directory> --locale <tag> --json."
    case let value where value.hasPrefix("CREATOR_PREVIEW_"):
        return "Correct the command options or output location, then rerun scripts/preview-content-pack.sh <pack-directory> --output <preview.html> --no-open."
    case let value where value.hasPrefix("CREATOR_PROJECTION_EDITOR_"):
        return "Correct the pack, video asset ID or output location, then rerun scripts/edit-content-pack-projection.sh <pack-directory> --no-open."
    default:
        return "Run scripts/doctor.sh and retry; if it still fails, attach the safe error code and receipt to a GitHub issue."
    }
}

struct CompanionFailureReceipt: Codable, Equatable, Sendable {
    let status: String
    let code: String
    let message: String
    let recoveryAction: String

    init(error: Error, fallbackCode: String) {
        status = "FAIL"
        code = companionErrorCode(for: error, fallback: fallbackCode)
        message = companionSafeFailureMessage(for: error)
        recoveryAction = companionRecoveryAction(for: code)
    }

    var safeLog: String {
        "FAIL  [\(code)] \(message)\nACTION  \(recoveryAction)"
    }
}

enum ContentPackValidationError: LocalizedError, Equatable, CompanionErrorCoding {
    case manifestMissing
    case manifestInvalidJSON
    case manifestTooLarge(actual: Int64, maximum: Int64)
    case unsupportedSchema(Int)
    case invalidIdentifier(String)
    case invalidSemanticVersion(String)
    case appVersionTooOld(required: String, current: String)
    case emptyCharacter
    case emptyLocales
    case duplicateLocale(String)
    case invalidLocale(String)
    case emptyLicense
    case tooManyFiles(actual: Int, maximum: Int)
    case unpackedSizeTooLarge(actual: Int64, maximum: Int64)
    case duplicateAssetID(String)
    case invalidAssetPath(String)
    case assetOutsidePackage(String)
    case assetMissing(String)
    case symbolicLinkNotAllowed(String)
    case hardLinkNotAllowed(String)
    case hiddenPathNotAllowed(String)
    case undeclaredFile(String)
    case caseInsensitivePathCollision(String)
    case unsupportedFileType(String)
    case executableNotAllowed(String)
    case invalidHash(String)
    case hashMismatch(path: String)
    case invalidVideoMetadata(String)
    case invalidCropAnchor(asset: String, mode: String)
    case invalidFocalTrack(asset: String, mode: String)
    case invalidSafeArea(asset: String, mode: String)
    case safeAreaNotVisible(asset: String, mode: String)
    case projectionFeatureRequiresAppVersion(asset: String, required: String)
    case workdayTriggerRequiresAppVersion(trigger: String, required: String)
    case unsupportedTrigger(String)
    case v2FeaturesRequireSchema2
    case tooManyExperiences(actual: Int, maximum: Int)
    case invalidExperienceIdentifier(String)
    case duplicateExperienceID(String)
    case emptyExperienceSteps(String)
    case tooManyExperienceSteps(experience: String, actual: Int, maximum: Int)
    case invalidExperienceWeight(String)
    case invalidExperienceCooldown(String)
    case emptyExperienceLocales(String)
    case invalidExperienceLocale(experience: String, locale: String)
    case unknownExperienceAsset(experience: String, asset: String)
    case nonVideoExperienceAsset(experience: String, asset: String)
    case invalidExperiencePlaybackDuration(experience: String, asset: String)
    case contributionRequiresSchema2
    case duplicateRightsAsset(String)
    case duplicateAccessibilityAsset(String)
    case unknownRightsAsset(String)
    case unknownAccessibilityAsset(String)
    case invalidRightsHolder(String)
    case invalidRightsLicense(String)
    case invalidRightsEvidenceID(String)
    case invalidRightsSourceHash(String)
    case invalidAccessibilityLocale(asset: String, locale: String)
    case emptyAccessibilityDescription(asset: String, locale: String)
    case invalidAccessibilityTranscript(asset: String, locale: String)
    case unsupportedContributionContract(Int)
    case strictPackageMetadataMissing
    case strictRightsMetadataMissing(String)
    case strictAccessibilityMetadataMissing(String)
    case strictFallbackMetadataMissing(String)
    case invalidPackageContributionField(String)
    case invalidRightsField(asset: String, field: String)
    case invalidAccessibilityField(asset: String, field: String)
    case duplicateFallbackAsset(String)
    case unknownFallbackAsset(String)
    case invalidAssetFallback(String)
    case unknownManifestField(String)
    case privatePathInContribution(String)
    case assetTooLarge(asset: String, actual: Int64, maximum: Int64)
    case mediaDimensionsTooLarge(String)
    case mediaDurationTooLong(String)
    case tooManyLocales(actual: Int, maximum: Int)
    case tooManyAssets(actual: Int, maximum: Int)
    case invalidAssetIdentifier(String)
    case duplicateAssetPath(String)

    var companionErrorCode: String {
        switch self {
        case .manifestMissing: "PACK_VALIDATION_MANIFEST_MISSING"
        case .manifestInvalidJSON: "PACK_VALIDATION_MANIFEST_INVALID_JSON"
        case .manifestTooLarge: "PACK_VALIDATION_MANIFEST_TOO_LARGE"
        case .unsupportedSchema: "PACK_VALIDATION_UNSUPPORTED_SCHEMA"
        case .invalidIdentifier: "PACK_VALIDATION_INVALID_IDENTIFIER"
        case .invalidSemanticVersion: "PACK_VALIDATION_INVALID_SEMVER"
        case .appVersionTooOld: "PACK_VALIDATION_APP_VERSION_TOO_OLD"
        case .emptyCharacter: "PACK_VALIDATION_CHARACTER_MISSING"
        case .emptyLocales: "PACK_VALIDATION_LOCALES_MISSING"
        case .duplicateLocale: "PACK_VALIDATION_DUPLICATE_LOCALE"
        case .invalidLocale: "PACK_VALIDATION_INVALID_LOCALE"
        case .emptyLicense: "PACK_VALIDATION_LICENSE_MISSING"
        case .tooManyFiles: "PACK_VALIDATION_TOO_MANY_FILES"
        case .unpackedSizeTooLarge: "PACK_VALIDATION_UNPACKED_SIZE_TOO_LARGE"
        case .duplicateAssetID: "PACK_VALIDATION_DUPLICATE_ASSET_ID"
        case .invalidAssetPath: "PACK_VALIDATION_INVALID_ASSET_PATH"
        case .assetOutsidePackage: "PACK_VALIDATION_PATH_TRAVERSAL"
        case .assetMissing: "PACK_VALIDATION_ASSET_MISSING"
        case .symbolicLinkNotAllowed: "PACK_VALIDATION_SYMBOLIC_LINK"
        case .hardLinkNotAllowed: "PACK_VALIDATION_HARD_LINK"
        case .hiddenPathNotAllowed: "PACK_VALIDATION_HIDDEN_PATH"
        case .undeclaredFile: "PACK_VALIDATION_UNDECLARED_FILE"
        case .caseInsensitivePathCollision: "PACK_VALIDATION_PATH_COLLISION"
        case .unsupportedFileType: "PACK_VALIDATION_UNSUPPORTED_FILE_TYPE"
        case .executableNotAllowed: "PACK_VALIDATION_EXECUTABLE_FILE"
        case .invalidHash: "PACK_VALIDATION_INVALID_SHA256"
        case .hashMismatch: "PACK_VALIDATION_SHA256_MISMATCH"
        case .invalidVideoMetadata: "PACK_VALIDATION_INVALID_VIDEO_METADATA"
        case .invalidCropAnchor: "PACK_VALIDATION_INVALID_CROP_ANCHOR"
        case .invalidFocalTrack: "PACK_VALIDATION_INVALID_FOCAL_TRACK"
        case .invalidSafeArea: "PACK_VALIDATION_INVALID_SAFE_AREA"
        case .safeAreaNotVisible: "PACK_VALIDATION_SAFE_AREA_NOT_VISIBLE"
        case .projectionFeatureRequiresAppVersion: "PACK_VALIDATION_PROJECTION_REQUIRES_APP_VERSION"
        case .workdayTriggerRequiresAppVersion: "PACK_VALIDATION_WORKDAY_TRIGGER_REQUIRES_APP_VERSION"
        case .unsupportedTrigger: "PACK_VALIDATION_UNSUPPORTED_TRIGGER"
        case .v2FeaturesRequireSchema2: "PACK_VALIDATION_V2_REQUIRES_SCHEMA_2"
        case .tooManyExperiences: "PACK_VALIDATION_TOO_MANY_EXPERIENCES"
        case .invalidExperienceIdentifier: "PACK_VALIDATION_INVALID_EXPERIENCE_ID"
        case .duplicateExperienceID: "PACK_VALIDATION_DUPLICATE_EXPERIENCE_ID"
        case .emptyExperienceSteps: "PACK_VALIDATION_EXPERIENCE_STEPS_MISSING"
        case .tooManyExperienceSteps: "PACK_VALIDATION_TOO_MANY_EXPERIENCE_STEPS"
        case .invalidExperienceWeight: "PACK_VALIDATION_INVALID_EXPERIENCE_WEIGHT"
        case .invalidExperienceCooldown: "PACK_VALIDATION_INVALID_EXPERIENCE_COOLDOWN"
        case .emptyExperienceLocales: "PACK_VALIDATION_EXPERIENCE_LOCALES_MISSING"
        case .invalidExperienceLocale: "PACK_VALIDATION_INVALID_EXPERIENCE_LOCALE"
        case .unknownExperienceAsset: "PACK_VALIDATION_UNKNOWN_EXPERIENCE_ASSET"
        case .nonVideoExperienceAsset: "PACK_VALIDATION_EXPERIENCE_ASSET_NOT_VIDEO"
        case .invalidExperiencePlaybackDuration: "PACK_VALIDATION_INVALID_PLAYBACK_DURATION"
        case .contributionRequiresSchema2: "PACK_VALIDATION_CONTRIBUTION_REQUIRES_SCHEMA_2"
        case .duplicateRightsAsset: "PACK_VALIDATION_DUPLICATE_RIGHTS_ASSET"
        case .duplicateAccessibilityAsset: "PACK_VALIDATION_DUPLICATE_ACCESSIBILITY_ASSET"
        case .unknownRightsAsset: "PACK_VALIDATION_UNKNOWN_RIGHTS_ASSET"
        case .unknownAccessibilityAsset: "PACK_VALIDATION_UNKNOWN_ACCESSIBILITY_ASSET"
        case .invalidRightsHolder: "PACK_VALIDATION_INVALID_RIGHTS_HOLDER"
        case .invalidRightsLicense: "PACK_VALIDATION_INVALID_RIGHTS_LICENSE"
        case .invalidRightsEvidenceID: "PACK_VALIDATION_INVALID_RIGHTS_EVIDENCE_ID"
        case .invalidRightsSourceHash: "PACK_VALIDATION_INVALID_RIGHTS_SOURCE_SHA256"
        case .invalidAccessibilityLocale: "PACK_VALIDATION_INVALID_ACCESSIBILITY_LOCALE"
        case .emptyAccessibilityDescription: "PACK_VALIDATION_ACCESSIBILITY_DESCRIPTION_MISSING"
        case .invalidAccessibilityTranscript: "PACK_VALIDATION_INVALID_ACCESSIBILITY_TRANSCRIPT"
        case .unsupportedContributionContract: "PACK_VALIDATION_UNSUPPORTED_CONTRIBUTION_CONTRACT"
        case .strictPackageMetadataMissing: "PACK_VALIDATION_STRICT_PACKAGE_METADATA_MISSING"
        case .strictRightsMetadataMissing: "PACK_VALIDATION_STRICT_RIGHTS_METADATA_MISSING"
        case .strictAccessibilityMetadataMissing: "PACK_VALIDATION_STRICT_ACCESSIBILITY_METADATA_MISSING"
        case .strictFallbackMetadataMissing: "PACK_VALIDATION_STRICT_FALLBACK_METADATA_MISSING"
        case .invalidPackageContributionField: "PACK_VALIDATION_INVALID_PACKAGE_CONTRIBUTION_FIELD"
        case .invalidRightsField: "PACK_VALIDATION_INVALID_RIGHTS_FIELD"
        case .invalidAccessibilityField: "PACK_VALIDATION_INVALID_ACCESSIBILITY_FIELD"
        case .duplicateFallbackAsset: "PACK_VALIDATION_DUPLICATE_FALLBACK_ASSET"
        case .unknownFallbackAsset: "PACK_VALIDATION_UNKNOWN_FALLBACK_ASSET"
        case .invalidAssetFallback: "PACK_VALIDATION_INVALID_ASSET_FALLBACK"
        case .unknownManifestField: "PACK_VALIDATION_UNKNOWN_MANIFEST_FIELD"
        case .privatePathInContribution: "PACK_VALIDATION_PRIVATE_PATH_DISCLOSURE"
        case .assetTooLarge: "PACK_VALIDATION_ASSET_TOO_LARGE"
        case .mediaDimensionsTooLarge: "PACK_VALIDATION_MEDIA_DIMENSIONS_TOO_LARGE"
        case .mediaDurationTooLong: "PACK_VALIDATION_MEDIA_DURATION_TOO_LONG"
        case .tooManyLocales: "PACK_VALIDATION_TOO_MANY_LOCALES"
        case .tooManyAssets: "PACK_VALIDATION_TOO_MANY_ASSETS"
        case .invalidAssetIdentifier: "PACK_VALIDATION_INVALID_ASSET_ID"
        case .duplicateAssetPath: "PACK_VALIDATION_DUPLICATE_ASSET_PATH"
        }
    }

    var errorDescription: String? {
        switch self {
        case .manifestMissing:
            return "The content pack is missing manifest.json."
        case .manifestInvalidJSON:
            return "manifest.json is not valid Content Pack JSON."
        case let .manifestTooLarge(actual, maximum):
            return "manifest.json is \(actual) bytes, above the \(maximum)-byte limit."
        case let .unsupportedSchema(version):
            return "Content-pack schemaVersion \(version) is not supported."
        case let .invalidIdentifier(identifier):
            return "The content-pack ID is invalid: \(identifier)."
        case let .invalidSemanticVersion(version):
            return "The version is not valid SemVer: \(version)."
        case let .appVersionTooOld(required, current):
            return "This pack requires Chengyin \(required) or newer; current is \(current)."
        case .emptyCharacter:
            return "The content pack does not declare a character."
        case .emptyLocales:
            return "The content pack does not declare any locales."
        case let .duplicateLocale(locale):
            return "The content pack declares locale \(locale) more than once."
        case let .invalidLocale(locale):
            return "The content pack locale is invalid: \(locale)."
        case .emptyLicense:
            return "The content pack does not declare a content license."
        case let .tooManyFiles(actual, maximum):
            return "The pack contains \(actual) files, above the \(maximum)-file limit."
        case let .unpackedSizeTooLarge(actual, maximum):
            return "The unpacked pack is \(actual) bytes, above the \(maximum)-byte limit."
        case let .duplicateAssetID(identifier):
            return "The asset ID is duplicated: \(identifier)."
        case let .invalidAssetPath(path):
            return "The asset path is invalid: \(path)."
        case let .assetOutsidePackage(path):
            return "The asset path escapes the pack directory: \(path)."
        case let .assetMissing(path):
            return "The declared asset is missing: \(path)."
        case let .symbolicLinkNotAllowed(path):
            return "Symbolic links are not allowed in content packs: \(path)."
        case let .hardLinkNotAllowed(path):
            return "Hard links are not allowed in content packs: \(path)."
        case let .hiddenPathNotAllowed(path):
            return "Hidden paths are not allowed in content packs: \(path)."
        case let .undeclaredFile(path):
            return "The pack contains a file not declared by the manifest: \(path)."
        case let .caseInsensitivePathCollision(path):
            return "The pack contains a case-insensitive path collision: \(path)."
        case let .unsupportedFileType(path):
            return "The pack contains an unsupported file type: \(path)."
        case let .executableNotAllowed(path):
            return "Executable files are not allowed in content packs: \(path)."
        case let .invalidHash(path):
            return "The asset does not declare a valid SHA-256: \(path)."
        case let .hashMismatch(path):
            return "The asset SHA-256 does not match: \(path)."
        case let .invalidVideoMetadata(asset):
            return "The declared video metadata is invalid: \(asset)."
        case let .invalidCropAnchor(asset, mode):
            return "Asset \(asset) has an invalid \(mode) crop anchor."
        case let .invalidFocalTrack(asset, mode):
            return "Asset \(asset) has an invalid \(mode) focal track."
        case let .invalidSafeArea(asset, mode):
            return "Asset \(asset) has an invalid \(mode) safe area."
        case let .safeAreaNotVisible(asset, mode):
            return "Asset \(asset) does not keep its \(mode) safe area visible."
        case let .projectionFeatureRequiresAppVersion(asset, required):
            return "Asset \(asset) uses dynamic projection fields that require Chengyin \(required) or newer."
        case let .workdayTriggerRequiresAppVersion(trigger, required):
            return "Trigger \(trigger) requires Chengyin \(required) or newer."
        case let .unsupportedTrigger(trigger):
            return "The content pack uses an unsupported trigger: \(trigger)."
        case .v2FeaturesRequireSchema2:
            return "Experiences, focal tracks and safe areas require schemaVersion 2."
        case let .tooManyExperiences(actual, maximum):
            return "The pack declares \(actual) experiences, above the \(maximum)-experience limit."
        case let .invalidExperienceIdentifier(identifier):
            return "The experience ID is invalid: \(identifier)."
        case let .duplicateExperienceID(identifier):
            return "The experience ID is duplicated: \(identifier)."
        case let .emptyExperienceSteps(identifier):
            return "Experience \(identifier) does not declare any steps."
        case let .tooManyExperienceSteps(experience, actual, maximum):
            return "Experience \(experience) has \(actual) steps, above the \(maximum)-step limit."
        case let .invalidExperienceWeight(identifier):
            return "Experience \(identifier) weight must be between 0.01 and 100."
        case let .invalidExperienceCooldown(identifier):
            return "Experience \(identifier) cooldownSeconds is outside the supported range."
        case let .emptyExperienceLocales(identifier):
            return "Experience \(identifier) locales must not be empty."
        case let .invalidExperienceLocale(experience, locale):
            return "Experience \(experience) uses undeclared or invalid locale \(locale)."
        case let .unknownExperienceAsset(experience, asset):
            return "Experience \(experience) references an unknown asset: \(asset)."
        case let .nonVideoExperienceAsset(experience, asset):
            return "Experience \(experience) step asset must be video: \(asset)."
        case let .invalidExperiencePlaybackDuration(experience, asset):
            return "Experience \(experience) has an invalid minimum playback duration for \(asset)."
        case .contributionRequiresSchema2:
            return "Contribution metadata requires schemaVersion 2."
        case let .duplicateRightsAsset(asset):
            return "Rights metadata is duplicated for asset \(asset)."
        case let .duplicateAccessibilityAsset(asset):
            return "Accessibility metadata is duplicated for asset \(asset)."
        case let .unknownRightsAsset(asset):
            return "Rights metadata references an unknown asset: \(asset)."
        case let .unknownAccessibilityAsset(asset):
            return "Accessibility metadata references an unknown asset: \(asset)."
        case let .invalidRightsHolder(asset):
            return "Asset \(asset) has an invalid rights holder."
        case let .invalidRightsLicense(asset):
            return "Asset \(asset) has an invalid rights license."
        case let .invalidRightsEvidenceID(asset):
            return "Asset \(asset) has an invalid opaque rights evidence ID."
        case let .invalidRightsSourceHash(asset):
            return "Asset \(asset) has an invalid source SHA-256."
        case let .invalidAccessibilityLocale(asset, locale):
            return "Asset \(asset) has accessibility copy for undeclared locale \(locale)."
        case let .emptyAccessibilityDescription(asset, locale):
            return "Asset \(asset) has an empty accessibility description for \(locale)."
        case let .invalidAccessibilityTranscript(asset, locale):
            return "Asset \(asset) has an invalid accessibility transcript for \(locale)."
        case let .unsupportedContributionContract(version):
            return "Contribution contract version \(version) is not supported."
        case .strictPackageMetadataMissing:
            return "Strict contribution mode requires package-level provenance and review metadata."
        case let .strictRightsMetadataMissing(asset):
            return "Strict contribution mode requires a rights record for asset \(asset)."
        case let .strictAccessibilityMetadataMissing(asset):
            return "Strict contribution mode requires an accessibility record for asset \(asset)."
        case let .strictFallbackMetadataMissing(asset):
            return "Strict contribution mode requires a fallback declaration for asset \(asset)."
        case let .invalidPackageContributionField(field):
            return "Package contribution field \(field) is invalid or incomplete."
        case let .invalidRightsField(asset, field):
            return "Asset \(asset) has an invalid or incomplete rights field: \(field)."
        case let .invalidAccessibilityField(asset, field):
            return "Asset \(asset) has an invalid or incomplete accessibility field: \(field)."
        case let .duplicateFallbackAsset(asset):
            return "Fallback metadata is duplicated for asset \(asset)."
        case let .unknownFallbackAsset(asset):
            return "Fallback metadata references an unknown asset: \(asset)."
        case let .invalidAssetFallback(asset):
            return "Asset \(asset) has an invalid fallback strategy for its asset kind."
        case let .unknownManifestField(field):
            return "The manifest contains an unknown field: \(field)."
        case let .privatePathInContribution(scope):
            return "Contribution metadata in \(scope) appears to disclose a private local path."
        case let .assetTooLarge(asset, actual, maximum):
            return "Asset \(asset) is \(actual) bytes, above the \(maximum)-byte single-asset limit."
        case let .mediaDimensionsTooLarge(asset):
            return "Asset \(asset) exceeds the supported media pixel limit."
        case let .mediaDurationTooLong(asset):
            return "Asset \(asset) exceeds the supported media duration limit."
        case let .tooManyLocales(actual, maximum):
            return "The pack declares \(actual) locales, above the \(maximum)-locale limit."
        case let .tooManyAssets(actual, maximum):
            return "The pack declares \(actual) assets, above the \(maximum)-asset limit."
        case let .invalidAssetIdentifier(asset):
            return "The asset ID is invalid: \(asset)."
        case let .duplicateAssetPath(path):
            return "More than one asset declares the same path: \(path)."
        }
    }
}
