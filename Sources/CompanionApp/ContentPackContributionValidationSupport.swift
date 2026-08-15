import Foundation

/// Shared value-only rules used by the focused Content Pack v2 contribution
/// validators. The scope is semantic and path-free so error mapping cannot
/// accidentally disclose a local package location.
enum ContentPackContributionValidationScope: Equatable {
    case package
    case rights(assetID: String)
    case accessibility(assetID: String)

    var privacySafeLabel: String {
        switch self {
        case .package:
            return "package"
        case .rights(let assetID):
            return "asset \(assetID)"
        case .accessibility(let assetID):
            return "asset \(assetID) accessibility"
        }
    }
}

enum ContentPackContributionValidationSupport {
    static let hashPattern = #"^[a-f0-9]{64}$"#
    static let evidenceIdentifierPattern =
        #"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$"#

    static func validateText(
        _ value: String,
        scope: ContentPackContributionValidationScope,
        field: String,
        maximum: Int
    ) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maximum else {
            throw invalidField(scope: scope, field: field)
        }
        if appearsToDisclosePrivatePath(trimmed) {
            throw ContentPackValidationError.privatePathInContribution(
                scope.privacySafeLabel
            )
        }
    }

    static func validateAttribution(
        _ attribution: ContentPackAttributionRequirement,
        scope: ContentPackContributionValidationScope
    ) throws {
        let trimmed = attribution.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard (!attribution.required || !trimmed.isEmpty), trimmed.count <= 1_000 else {
            throw invalidField(scope: scope, field: "attribution")
        }
        if appearsToDisclosePrivatePath(trimmed) {
            throw ContentPackValidationError.privatePathInContribution(
                scope.privacySafeLabel
            )
        }
    }

    static func validateReview(
        _ review: ContentPackReviewRecord,
        scope: ContentPackContributionValidationScope
    ) throws {
        guard (1...10_000).contains(review.version) else {
            throw invalidField(scope: scope, field: "review.version")
        }
        if let reviewerID = review.reviewerID,
           !matches(reviewerID, pattern: evidenceIdentifierPattern) {
            throw invalidField(scope: scope, field: "review.reviewerID")
        }
        if review.status == .approved, review.reviewerID == nil {
            throw invalidField(scope: scope, field: "review.reviewerID")
        }
    }

    static func validateLocalizedAccessibility(
        _ values: [String: String],
        assetID: String,
        field: String,
        maximum: Int,
        declaredLocales: Set<String>
    ) throws {
        for (locale, value) in values {
            guard declaredLocales.contains(locale) else {
                throw ContentPackValidationError.invalidAccessibilityLocale(
                    asset: assetID,
                    locale: locale
                )
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= maximum else {
                throw ContentPackValidationError.invalidAccessibilityField(
                    asset: assetID,
                    field: "\(field).\(locale)"
                )
            }
        }
    }

    static func matches(_ string: String, pattern: String) -> Bool {
        string.range(of: pattern, options: .regularExpression) != nil
    }

    private static func invalidField(
        scope: ContentPackContributionValidationScope,
        field: String
    ) -> ContentPackValidationError {
        switch scope {
        case .package:
            return .invalidPackageContributionField(field)
        case .rights(let assetID):
            return .invalidRightsField(asset: assetID, field: field)
        case .accessibility(let assetID):
            return .invalidAccessibilityField(asset: assetID, field: field)
        }
    }

    private static func appearsToDisclosePrivatePath(_ value: String) -> Bool {
        let lowered = value.lowercased()
        return lowered.hasPrefix("~/")
            || lowered.hasPrefix("/users/")
            || lowered.hasPrefix("/home/")
            || lowered.hasPrefix("file://")
            || lowered.contains("/users/")
            || lowered.contains("/home/")
            || lowered.contains("\\users\\")
            || value.range(
                of: #"^[A-Za-z]:\\"#,
                options: .regularExpression
            ) != nil
    }
}
