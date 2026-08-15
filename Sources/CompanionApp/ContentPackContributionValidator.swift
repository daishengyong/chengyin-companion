/// Orchestrates the pure Content Pack v2 contribution policies without owning
/// rights, accessibility, fallback or shared-field implementation details.
struct ContentPackContributionValidator {
    private let rightsValidator = ContentPackRightsValidator()
    private let accessibilityValidator = ContentPackAccessibilityValidator()
    private let fallbackValidator = ContentPackFallbackValidator()

    func validate(
        _ contribution: ContentPackContributionMetadata?,
        schemaVersion: Int,
        assetsByID: [String: ContentPackAsset],
        declaredLocales: Set<String>
    ) throws {
        guard let contribution else { return }
        guard schemaVersion >= 2 else {
            throw ContentPackValidationError.contributionRequiresSchema2
        }
        if let contractVersion = contribution.contractVersion,
           contractVersion != 2 {
            throw ContentPackValidationError.unsupportedContributionContract(
                contractVersion
            )
        }
        let strict = contribution.contractVersion == 2
        try rightsValidator.validate(
            package: contribution.package,
            rights: contribution.rights,
            strict: strict,
            assetsByID: assetsByID
        )
        try accessibilityValidator.validate(
            contribution.accessibility,
            strict: strict,
            assetsByID: assetsByID,
            declaredLocales: declaredLocales
        )
        try fallbackValidator.validate(
            contribution.fallback,
            strict: strict,
            assetsByID: assetsByID
        )
    }
}
