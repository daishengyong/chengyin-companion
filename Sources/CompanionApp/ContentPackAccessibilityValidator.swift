import Foundation

/// Pure per-locale accessibility metadata and review validation.
struct ContentPackAccessibilityValidator {
    func validate(
        _ accessibilityEntries: [ContentPackAssetAccessibility],
        strict: Bool,
        assetsByID: [String: ContentPackAsset],
        declaredLocales: Set<String>
    ) throws {
        var accessibilityAssetIDs = Set<String>()
        for accessibility in accessibilityEntries {
            guard accessibilityAssetIDs.insert(accessibility.assetID).inserted else {
                throw ContentPackValidationError.duplicateAccessibilityAsset(
                    accessibility.assetID
                )
            }
            guard let asset = assetsByID[accessibility.assetID] else {
                throw ContentPackValidationError.unknownAccessibilityAsset(
                    accessibility.assetID
                )
            }
            try validateDescriptions(
                accessibility.descriptions,
                assetID: accessibility.assetID,
                declaredLocales: declaredLocales
            )
            try validateTranscripts(
                accessibility.transcripts ?? [:],
                assetID: accessibility.assetID,
                declaredLocales: declaredLocales
            )
            try ContentPackContributionValidationSupport.validateLocalizedAccessibility(
                accessibility.altText ?? [:],
                assetID: accessibility.assetID,
                field: "altText",
                maximum: 1_000,
                declaredLocales: declaredLocales
            )
            try ContentPackContributionValidationSupport.validateLocalizedAccessibility(
                accessibility.captions ?? [:],
                assetID: accessibility.assetID,
                field: "captions",
                maximum: 8_000,
                declaredLocales: declaredLocales
            )
            try ContentPackContributionValidationSupport.validateLocalizedAccessibility(
                accessibility.soundDescriptions ?? [:],
                assetID: accessibility.assetID,
                field: "soundDescriptions",
                maximum: 8_000,
                declaredLocales: declaredLocales
            )
            if let review = accessibility.review {
                try ContentPackContributionValidationSupport.validateReview(
                    review,
                    scope: .accessibility(assetID: accessibility.assetID)
                )
            }
            if strict {
                try validateStrictAccessibility(
                    accessibility,
                    asset: asset,
                    declaredLocales: declaredLocales
                )
            }
        }
        if strict {
            for assetID in assetsByID.keys
            where !accessibilityAssetIDs.contains(assetID) {
                throw ContentPackValidationError.strictAccessibilityMetadataMissing(
                    assetID
                )
            }
        }
    }

    private func validateDescriptions(
        _ descriptions: [String: String],
        assetID: String,
        declaredLocales: Set<String>
    ) throws {
        for (locale, description) in descriptions {
            guard declaredLocales.contains(locale) else {
                throw ContentPackValidationError.invalidAccessibilityLocale(
                    asset: assetID,
                    locale: locale
                )
            }
            let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 1_000 else {
                throw ContentPackValidationError.emptyAccessibilityDescription(
                    asset: assetID,
                    locale: locale
                )
            }
        }
    }

    private func validateTranscripts(
        _ transcripts: [String: String],
        assetID: String,
        declaredLocales: Set<String>
    ) throws {
        for (locale, transcript) in transcripts {
            guard declaredLocales.contains(locale) else {
                throw ContentPackValidationError.invalidAccessibilityLocale(
                    asset: assetID,
                    locale: locale
                )
            }
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 8_000 else {
                throw ContentPackValidationError.invalidAccessibilityTranscript(
                    asset: assetID,
                    locale: locale
                )
            }
        }
    }

    private func validateStrictAccessibility(
        _ accessibility: ContentPackAssetAccessibility,
        asset: ContentPackAsset,
        declaredLocales: Set<String>
    ) throws {
        for locale in declaredLocales
        where accessibility.descriptions[locale] == nil {
            throw ContentPackValidationError.invalidAccessibilityField(
                asset: accessibility.assetID,
                field: "descriptions.\(locale)"
            )
        }
        if asset.kind == .video || asset.kind == .image {
            for locale in declaredLocales
            where accessibility.altText?[locale] == nil {
                throw ContentPackValidationError.invalidAccessibilityField(
                    asset: accessibility.assetID,
                    field: "altText.\(locale)"
                )
            }
        }
        let audible = asset.kind == .audio
            || (asset.kind == .video && asset.hasNativeAudio == true)
        if audible {
            for locale in declaredLocales
            where accessibility.captions?[locale] == nil {
                throw ContentPackValidationError.invalidAccessibilityField(
                    asset: accessibility.assetID,
                    field: "captions.\(locale)"
                )
            }
            for locale in declaredLocales
            where accessibility.soundDescriptions?[locale] == nil {
                throw ContentPackValidationError.invalidAccessibilityField(
                    asset: accessibility.assetID,
                    field: "soundDescriptions.\(locale)"
                )
            }
        }
        guard accessibility.review != nil else {
            throw ContentPackValidationError.invalidAccessibilityField(
                asset: accessibility.assetID,
                field: "review"
            )
        }
    }
}
