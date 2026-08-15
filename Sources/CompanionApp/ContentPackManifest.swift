import Foundation

#if canImport(CompanionContracts)
import CompanionContracts
#endif

struct ContentPackManifest: Codable, Equatable, Sendable {
    enum Tier: String, Codable, Sendable {
        case free
        case paid
        case local
    }

    let schemaVersion: Int
    let id: String
    let version: String
    let minAppVersion: String
    let tier: Tier
    let character: String
    let locales: [String]
    let assets: [ContentPackAsset]
    let license: String
    let experiences: [ContentPackExperience]?
    let contribution: ContentPackContributionMetadata?

    init(
        schemaVersion: Int,
        id: String,
        version: String,
        minAppVersion: String,
        tier: Tier,
        character: String,
        locales: [String],
        assets: [ContentPackAsset],
        license: String,
        experiences: [ContentPackExperience]? = nil,
        contribution: ContentPackContributionMetadata? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.version = version
        self.minAppVersion = minAppVersion
        self.tier = tier
        self.character = character
        self.locales = locales
        self.assets = assets
        self.license = license
        self.experiences = experiences
        self.contribution = contribution
    }
}

/// Reviewable contribution evidence. Opaque `evidenceID` values point into a
/// maintainer-controlled rights ledger without embedding local paths or URLs in
/// distributable packs.
struct ContentPackContributionMetadata: Codable, Equatable, Sendable {
    /// Absent means the pre-contract v2 compatibility shape. Version 2 opts
    /// into the strict, machine-verifiable contribution contract.
    let contractVersion: Int?
    let package: ContentPackPackageProvenance?
    let rights: [ContentPackAssetRights]
    let accessibility: [ContentPackAssetAccessibility]
    let fallback: ContentPackFallbackDeclaration

    init(
        contractVersion: Int? = nil,
        package: ContentPackPackageProvenance? = nil,
        rights: [ContentPackAssetRights],
        accessibility: [ContentPackAssetAccessibility],
        fallback: ContentPackFallbackDeclaration
    ) {
        self.contractVersion = contractVersion
        self.package = package
        self.rights = rights
        self.accessibility = accessibility
        self.fallback = fallback
    }
}

enum ContentPackAuthorizationBasis: String, Codable, Sendable {
    case owned
    case licensed
    case commissioned
    case providerOutput
    case publicDomain
}

enum ContentPackAllowedUse: String, Codable, Sendable, CaseIterable, Hashable {
    case useInApp
    case redistribution
    case modification
    case commercialUse
}

struct ContentPackAttributionRequirement: Codable, Equatable, Sendable {
    let required: Bool
    let text: String?
}

struct ContentPackReviewRecord: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        case draft
        case pending
        case approved
        case rejected
    }

    let status: Status
    let version: Int
    /// Opaque reviewer identity. It must never contain a local path or account
    /// home-directory fragment.
    let reviewerID: String?
}

struct ContentPackPackageProvenance: Codable, Equatable, Sendable {
    enum AdultFictionStatus: String, Codable, Sendable {
        case fictionalAdultsOnly
        case verifiedAdultsOnly
        case mixedVerifiedAndFictionalAdults
        case noPeople
    }

    let source: String
    let author: String
    let provider: String?
    let origin: ContentPackAssetRights.Origin
    let license: String
    let authorizationBasis: ContentPackAuthorizationBasis
    let allowedUses: [ContentPackAllowedUse]
    let attribution: ContentPackAttributionRequirement
    let adultFictionStatus: AdultFictionStatus
    let evidenceID: String
    let review: ContentPackReviewRecord
}

struct ContentPackAssetRights: Codable, Equatable, Sendable {
    enum Origin: String, Codable, Sendable {
        case original
        case generative
        case licensed
        case publicDomain
    }

    enum SubjectStatus: String, Codable, Sendable {
        case fictionalAdult
        case verifiedAdult
        case noPerson
        case notApplicable
    }

    let assetID: String
    let origin: Origin
    let holder: String
    let license: String
    let evidenceID: String
    let sourceSHA256: String?
    let commercialUseReviewed: Bool
    let subjectStatus: SubjectStatus
    /// Strict-v2 fields. They remain optional in Swift so packs authored
    /// before the strict contract continue to decode in compatibility mode.
    let source: String?
    let author: String?
    let provider: String?
    let authorizationBasis: ContentPackAuthorizationBasis?
    let allowedUses: [ContentPackAllowedUse]?
    let attribution: ContentPackAttributionRequirement?
    let review: ContentPackReviewRecord?

    init(
        assetID: String,
        origin: Origin,
        holder: String,
        license: String,
        evidenceID: String,
        sourceSHA256: String?,
        commercialUseReviewed: Bool,
        subjectStatus: SubjectStatus,
        source: String? = nil,
        author: String? = nil,
        provider: String? = nil,
        authorizationBasis: ContentPackAuthorizationBasis? = nil,
        allowedUses: [ContentPackAllowedUse]? = nil,
        attribution: ContentPackAttributionRequirement? = nil,
        review: ContentPackReviewRecord? = nil
    ) {
        self.assetID = assetID
        self.origin = origin
        self.holder = holder
        self.license = license
        self.evidenceID = evidenceID
        self.sourceSHA256 = sourceSHA256
        self.commercialUseReviewed = commercialUseReviewed
        self.subjectStatus = subjectStatus
        self.source = source
        self.author = author
        self.provider = provider
        self.authorizationBasis = authorizationBasis
        self.allowedUses = allowedUses
        self.attribution = attribution
        self.review = review
    }
}

struct ContentPackAssetAccessibility: Codable, Equatable, Sendable {
    let assetID: String
    let descriptions: [String: String]
    let transcripts: [String: String]?
    let altText: [String: String]?
    let captions: [String: String]?
    let soundDescriptions: [String: String]?
    let flashingLights: Bool
    let suddenLoudAudio: Bool
    let review: ContentPackReviewRecord?

    init(
        assetID: String,
        descriptions: [String: String],
        transcripts: [String: String]?,
        altText: [String: String]? = nil,
        captions: [String: String]? = nil,
        soundDescriptions: [String: String]? = nil,
        flashingLights: Bool,
        suddenLoudAudio: Bool,
        review: ContentPackReviewRecord? = nil
    ) {
        self.assetID = assetID
        self.descriptions = descriptions
        self.transcripts = transcripts
        self.altText = altText
        self.captions = captions
        self.soundDescriptions = soundDescriptions
        self.flashingLights = flashingLights
        self.suddenLoudAudio = suddenLoudAudio
        self.review = review
    }
}

struct ContentPackFallbackDeclaration: Codable, Equatable, Sendable {
    enum Strategy: String, Codable, Sendable {
        case starter
    }

    let strategy: Strategy
    let assets: [ContentPackAssetFallback]?

    init(strategy: Strategy, assets: [ContentPackAssetFallback]? = nil) {
        self.strategy = strategy
        self.assets = assets
    }
}

struct ContentPackAssetFallback: Codable, Equatable, Sendable {
    enum Strategy: String, Codable, Sendable {
        case starter
        case skip
    }

    let assetID: String
    let strategy: Strategy
}

enum ContentPackContributionMode: String, Codable, Equatable, Sendable {
    case legacyV1 = "legacy-v1"
    case compatibilityV2 = "compatibility-v2"
    case strictV2 = "strict-v2"
}

/// Derived quality signal for contribution review. Like Lab/Stable/Verified,
/// creators cannot self-assert this value; Core derives it from exhaustive
/// asset coverage and factual declarations.
struct ContentPackContributionReadiness: Equatable, Sendable {
    let assetCount: Int
    let rightsCoveredAssetCount: Int
    let accessibilityCoveredAssetCount: Int
    let commercialUseReviewComplete: Bool
    let visualSubjectStatusComplete: Bool
    let localizedDescriptionsComplete: Bool
    let speechTranscriptsComplete: Bool
    let hasStarterFallback: Bool
    let mode: ContentPackContributionMode
    let packageEvidenceComplete: Bool
    let explicitAccessibilityComplete: Bool
    let perAssetFallbackComplete: Bool
    let reviewComplete: Bool

    var isReady: Bool {
        mode == .strictV2
            && rightsCoveredAssetCount == assetCount
            && accessibilityCoveredAssetCount == assetCount
            && commercialUseReviewComplete
            && visualSubjectStatusComplete
            && localizedDescriptionsComplete
            && speechTranscriptsComplete
            && hasStarterFallback
            && packageEvidenceComplete
            && explicitAccessibilityComplete
            && perAssetFallbackComplete
            && reviewComplete
    }
}

extension ContentPackManifest {
    var contributionMode: ContentPackContributionMode {
        if schemaVersion == 1 { return .legacyV1 }
        return contribution?.contractVersion == 2 ? .strictV2 : .compatibilityV2
    }

    var contributionReadiness: ContentPackContributionReadiness {
        let rightsByAsset = Dictionary(
            uniqueKeysWithValues: (contribution?.rights ?? []).map {
                ($0.assetID, $0)
            }
        )
        let accessibilityByAsset = Dictionary(
            uniqueKeysWithValues: (contribution?.accessibility ?? []).map {
                ($0.assetID, $0)
            }
        )
        let assetIDs = Set(assets.map(\.id))
        let rightsCovered = assetIDs.intersection(Set(rightsByAsset.keys)).count
        let accessibilityCovered = assetIDs.intersection(
            Set(accessibilityByAsset.keys)
        ).count
        let commercialReviewComplete = assets.allSatisfy {
            rightsByAsset[$0.id]?.commercialUseReviewed == true
        }
        let visualSubjectStatusComplete = assets.allSatisfy { asset in
            guard asset.kind == .video || asset.kind == .image else { return true }
            guard let status = rightsByAsset[asset.id]?.subjectStatus else {
                return false
            }
            return status != .notApplicable
        }
        let localizedDescriptionsComplete = assets.allSatisfy { asset in
            guard let access = accessibilityByAsset[asset.id] else { return false }
            return locales.allSatisfy { access.descriptions[$0] != nil }
        }
        let speechTranscriptsComplete = assets.allSatisfy { asset in
            let requiresTranscript = asset.kind == .audio
                || (asset.kind == .video && asset.hasNativeAudio == true)
            guard requiresTranscript else { return true }
            guard let transcripts = accessibilityByAsset[asset.id]?.transcripts else {
                return false
            }
            return locales.allSatisfy { transcripts[$0] != nil }
        }
        let packageEvidenceComplete: Bool = {
            guard let package = contribution?.package else { return false }
            return !package.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !package.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !package.license.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && package.allowedUses.contains(.useInApp)
                && package.allowedUses.contains(.redistribution)
                && package.allowedUses.contains(.modification)
                && package.allowedUses.contains(.commercialUse)
                && package.review.status == .approved
        }()
        let explicitAccessibilityComplete = assets.allSatisfy { asset in
            guard let access = accessibilityByAsset[asset.id] else { return false }
            let visualComplete = ![.video, .image].contains(asset.kind)
                || locales.allSatisfy { access.altText?[$0] != nil }
            let audible = asset.kind == .audio
                || (asset.kind == .video && asset.hasNativeAudio == true)
            let audibleComplete = !audible || locales.allSatisfy {
                access.captions?[$0] != nil && access.soundDescriptions?[$0] != nil
            }
            return visualComplete && audibleComplete
        }
        let fallbackByAsset = Dictionary(
            uniqueKeysWithValues: (contribution?.fallback.assets ?? []).map {
                ($0.assetID, $0)
            }
        )
        let perAssetFallbackComplete = assets.allSatisfy { asset in
            guard let fallback = fallbackByAsset[asset.id] else { return false }
            switch asset.kind {
            case .video, .audio, .image:
                return fallback.strategy == .starter
            case .game, .localization:
                return fallback.strategy == .starter || fallback.strategy == .skip
            }
        }
        let reviewComplete = assets.allSatisfy { asset in
            rightsByAsset[asset.id]?.review?.status == .approved
                && accessibilityByAsset[asset.id]?.review?.status == .approved
        }
        return ContentPackContributionReadiness(
            assetCount: assets.count,
            rightsCoveredAssetCount: rightsCovered,
            accessibilityCoveredAssetCount: accessibilityCovered,
            commercialUseReviewComplete: commercialReviewComplete,
            visualSubjectStatusComplete: visualSubjectStatusComplete,
            localizedDescriptionsComplete: localizedDescriptionsComplete,
            speechTranscriptsComplete: speechTranscriptsComplete,
            hasStarterFallback: contribution?.fallback.strategy == .starter,
            mode: contributionMode,
            packageEvidenceComplete: packageEvidenceComplete,
            explicitAccessibilityComplete: explicitAccessibilityComplete,
            perAssetFallbackComplete: perAssetFallbackComplete,
            reviewComplete: reviewComplete
        )
    }
}

struct ContentPackAsset: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case video
        case audio
        case image
        case game
        case localization
    }

    struct CropAnchor: Codable, Equatable, Sendable {
        let x: Double
        let y: Double
        let scale: Double
    }

    struct FocalKeyframe: Codable, Equatable, Sendable {
        let timeMs: Int
        let x: Double
        let y: Double
        let scale: Double
    }

    struct SafeArea: Codable, Equatable, Sendable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    let id: String
    let kind: Kind
    let path: String
    let sha256: String
    let durationMs: Int?
    let width: Int?
    let height: Int?
    let aspectRatio: String?
    let hasNativeAudio: Bool?
    let loop: Bool?
    let cropAnchors: [String: CropAnchor]?
    let focalTracks: [String: [FocalKeyframe]]?
    let safeAreas: [String: SafeArea]?
    let triggers: [String]
    let tags: [String]
    let cooldownSeconds: Int?
    let weight: Double?

    init(
        id: String,
        kind: Kind,
        path: String,
        sha256: String,
        durationMs: Int?,
        width: Int?,
        height: Int?,
        aspectRatio: String?,
        hasNativeAudio: Bool?,
        loop: Bool?,
        cropAnchors: [String: CropAnchor]?,
        focalTracks: [String: [FocalKeyframe]]? = nil,
        safeAreas: [String: SafeArea]? = nil,
        triggers: [String],
        tags: [String],
        cooldownSeconds: Int?,
        weight: Double?
    ) {
        self.id = id
        self.kind = kind
        self.path = path
        self.sha256 = sha256
        self.durationMs = durationMs
        self.width = width
        self.height = height
        self.aspectRatio = aspectRatio
        self.hasNativeAudio = hasNativeAudio
        self.loop = loop
        self.cropAnchors = cropAnchors
        self.focalTracks = focalTracks
        self.safeAreas = safeAreas
        self.triggers = triggers
        self.tags = tags
        self.cooldownSeconds = cooldownSeconds
        self.weight = weight
    }
}

struct ContentPackExperience: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case reaction
        case ritual
        case sceneStory
        case microGameReward
    }

    enum ReturnPolicy: String, Codable, Sendable {
        case previousMode
        case keepCurrentMode
        case remainExpanded
    }

    let id: String
    let kind: Kind
    let triggers: [String]
    let steps: [ContentPackExperienceStep]
    let locales: [String]?
    let cooldownSeconds: Int?
    let weight: Double?
    let returnPolicy: ReturnPolicy
}

struct ContentPackExperienceStep: Codable, Equatable, Sendable {
    enum Role: String, Codable, Sendable {
        case enter
        case notice
        case react
        case settle
        case exit
    }

    enum Transition: String, Codable, Sendable {
        case cut
        case crossfade
    }

    let assetID: String
    let role: Role
    let minimumPlaybackMs: Int?
    let transition: Transition?
}
