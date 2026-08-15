import Foundation

/// Pure package- and asset-level provenance and authorization validation.
struct ContentPackRightsValidator {
    func validate(
        package: ContentPackPackageProvenance?,
        rights: [ContentPackAssetRights],
        strict: Bool,
        assetsByID: [String: ContentPackAsset]
    ) throws {
        if strict, package == nil {
            throw ContentPackValidationError.strictPackageMetadataMissing
        }
        if let package {
            try validatePackageProvenance(package)
        }

        var rightsAssetIDs = Set<String>()
        for rights in rights {
            guard rightsAssetIDs.insert(rights.assetID).inserted else {
                throw ContentPackValidationError.duplicateRightsAsset(rights.assetID)
            }
            guard assetsByID[rights.assetID] != nil else {
                throw ContentPackValidationError.unknownRightsAsset(rights.assetID)
            }
            let holder = rights.holder.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !holder.isEmpty, holder.count <= 256 else {
                throw ContentPackValidationError.invalidRightsHolder(rights.assetID)
            }
            let license = rights.license.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !license.isEmpty, license.count <= 256 else {
                throw ContentPackValidationError.invalidRightsLicense(rights.assetID)
            }
            guard ContentPackContributionValidationSupport.matches(
                rights.evidenceID,
                pattern: ContentPackContributionValidationSupport.evidenceIdentifierPattern
            ) else {
                throw ContentPackValidationError.invalidRightsEvidenceID(rights.assetID)
            }
            if let sourceHash = rights.sourceSHA256,
               !ContentPackContributionValidationSupport.matches(
                   sourceHash,
                   pattern: ContentPackContributionValidationSupport.hashPattern
               ) {
                throw ContentPackValidationError.invalidRightsSourceHash(rights.assetID)
            }
            let scope = ContentPackContributionValidationScope.rights(
                assetID: rights.assetID
            )
            if let source = rights.source {
                try ContentPackContributionValidationSupport.validateText(
                    source,
                    scope: scope,
                    field: "source",
                    maximum: 512
                )
            }
            if let author = rights.author {
                try ContentPackContributionValidationSupport.validateText(
                    author,
                    scope: scope,
                    field: "author",
                    maximum: 256
                )
            }
            if let provider = rights.provider {
                try ContentPackContributionValidationSupport.validateText(
                    provider,
                    scope: scope,
                    field: "provider",
                    maximum: 256
                )
            }
            if let uses = rights.allowedUses {
                guard !uses.isEmpty, Set(uses).count == uses.count else {
                    throw ContentPackValidationError.invalidRightsField(
                        asset: rights.assetID,
                        field: "allowedUses"
                    )
                }
            }
            if let attribution = rights.attribution {
                try ContentPackContributionValidationSupport.validateAttribution(
                    attribution,
                    scope: scope
                )
            }
            if let review = rights.review {
                try ContentPackContributionValidationSupport.validateReview(
                    review,
                    scope: scope
                )
            }
            if strict {
                try validateStrictRights(rights)
            }
        }
        if strict {
            for assetID in assetsByID.keys where !rightsAssetIDs.contains(assetID) {
                throw ContentPackValidationError.strictRightsMetadataMissing(assetID)
            }
        }
    }

    private func validatePackageProvenance(
        _ package: ContentPackPackageProvenance
    ) throws {
        let scope = ContentPackContributionValidationScope.package
        try ContentPackContributionValidationSupport.validateText(
            package.source,
            scope: scope,
            field: "source",
            maximum: 512
        )
        try ContentPackContributionValidationSupport.validateText(
            package.author,
            scope: scope,
            field: "author",
            maximum: 256
        )
        if let provider = package.provider {
            try ContentPackContributionValidationSupport.validateText(
                provider,
                scope: scope,
                field: "provider",
                maximum: 256
            )
        }
        try ContentPackContributionValidationSupport.validateText(
            package.license,
            scope: scope,
            field: "license",
            maximum: 256
        )
        guard ContentPackContributionValidationSupport.matches(
            package.evidenceID,
            pattern: ContentPackContributionValidationSupport.evidenceIdentifierPattern
        ) else {
            throw ContentPackValidationError.invalidPackageContributionField(
                "evidenceID"
            )
        }
        guard !package.allowedUses.isEmpty,
              Set(package.allowedUses).count == package.allowedUses.count else {
            throw ContentPackValidationError.invalidPackageContributionField(
                "allowedUses"
            )
        }
        try ContentPackContributionValidationSupport.validateAttribution(
            package.attribution,
            scope: scope
        )
        try ContentPackContributionValidationSupport.validateReview(
            package.review,
            scope: scope
        )
    }

    private func validateStrictRights(_ rights: ContentPackAssetRights) throws {
        for (present, field) in [
            (rights.source != nil, "source"),
            (rights.author != nil, "author"),
            (rights.authorizationBasis != nil, "authorizationBasis"),
            (rights.allowedUses?.isEmpty == false, "allowedUses"),
            (rights.attribution != nil, "attribution"),
            (rights.review != nil, "review"),
        ] where !present {
            throw ContentPackValidationError.invalidRightsField(
                asset: rights.assetID,
                field: field
            )
        }
    }
}
