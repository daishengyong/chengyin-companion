import Foundation

struct ContentPackPlaybackReference: Equatable, Sendable {
    let packID: String
    let version: String
    let health: ContentPackHealthStatus
}

struct CompanionVideoAsset: Identifiable, Equatable, Sendable {
    let id: String
    let url: URL
    let hasNativeAudio: Bool
    let loops: Bool
    let cropAnchors: [String: ContentPackAsset.CropAnchor]
    let focalTracks: [String: [ContentPackAsset.FocalKeyframe]]
    let safeAreas: [String: ContentPackAsset.SafeArea]
    let localeTags: [String]
    let weight: Double
    let cooldownSeconds: Int
    let durationMs: Int?
    let accessibility: CompanionRuntimeMediaAccessibility?
    let packReference: ContentPackPlaybackReference?

    static func bundled(
        id: String,
        url: URL,
        hasNativeAudio: Bool = false,
        loops: Bool = true
    ) -> CompanionVideoAsset {
        CompanionVideoAsset(
            id: "bundle:\(id)",
            url: url,
            hasNativeAudio: hasNativeAudio,
            loops: loops,
            cropAnchors: [:],
            focalTracks: [:],
            safeAreas: [:],
            localeTags: [],
            weight: 1,
            cooldownSeconds: 0,
            durationMs: nil,
            accessibility: nil,
            packReference: nil
        )
    }
}

/// Caller-owned playback memory used by the content director.
///
/// `recentAssetIDs` is ordered newest first. Keeping playback state outside the
/// immutable catalog lets the app persist or reset memory without coupling it
/// to pack installation state.
struct ContentPackSelectionContext: Equatable, Sendable {
    let now: Date
    let recentAssetIDs: [String]
    let lastPlayedAtByAssetID: [String: Date]
    let recentExclusionLimit: Int

    init(
        now: Date = Date(),
        recentAssetIDs: [String] = [],
        lastPlayedAtByAssetID: [String: Date] = [:],
        recentExclusionLimit: Int = 6
    ) {
        self.now = now
        self.recentAssetIDs = recentAssetIDs
        self.lastPlayedAtByAssetID = lastPlayedAtByAssetID
        self.recentExclusionLimit = max(0, recentExclusionLimit)
    }
}

/// Selection metadata is useful for diagnostics without leaking content into
/// companion events. `usedFallbackTrigger` only describes local routing.
struct ContentPackVideoSelection: Equatable, Sendable {
    let asset: CompanionVideoAsset
    let trigger: String
    let usedFallbackTrigger: Bool
}

struct CompanionVideoSequenceStep: Equatable, Sendable {
    let asset: CompanionVideoAsset
    let role: ContentPackExperienceStep.Role
    let minimumPlaybackMs: Int
    let transition: ContentPackExperienceStep.Transition
}

struct CompanionVideoSequence: Identifiable, Equatable, Sendable {
    let id: String
    let kind: ContentPackExperience.Kind
    let steps: [CompanionVideoSequenceStep]
    let returnPolicy: ContentPackExperience.ReturnPolicy
    let localeTags: [String]
    let weight: Double
    let cooldownSeconds: Int
    let packReference: ContentPackPlaybackReference

    var videos: [CompanionVideoAsset] {
        steps.map(\.asset)
    }

    var estimatedDuration: TimeInterval {
        let milliseconds = steps.reduce(0) { partial, step in
            partial + max(step.minimumPlaybackMs, step.asset.durationMs ?? 0)
        }
        return TimeInterval(milliseconds) / 1_000
    }
}

/// Small deterministic state machine shared by the SwiftUI player and smoke
/// checks. Stale callbacks from a replaced AVPlayer item are ignored instead
/// of accidentally advancing a newer experience.
struct CompanionSequencePlaybackCursor: Equatable, Sendable {
    enum Advance: Equatable, Sendable {
        case ignored
        case showStep(Int)
        case completed
    }

    private(set) var sequenceID: String
    private(set) var stepCount: Int
    private(set) var currentIndex: Int
    private(set) var isCompleted: Bool

    init(sequenceID: String, stepCount: Int) {
        self.sequenceID = sequenceID
        self.stepCount = max(0, stepCount)
        currentIndex = 0
        isCompleted = stepCount == 0
    }

    mutating func reset(sequenceID: String, stepCount: Int) {
        self = CompanionSequencePlaybackCursor(
            sequenceID: sequenceID,
            stepCount: stepCount
        )
    }

    mutating func stepEnded(
        sequenceID: String,
        index: Int
    ) -> Advance {
        guard !isCompleted,
              sequenceID == self.sequenceID,
              index == currentIndex else {
            return .ignored
        }
        if currentIndex + 1 < stepCount {
            currentIndex += 1
            return .showStep(currentIndex)
        }
        isCompleted = true
        return .completed
    }
}

struct ContentPackExperienceSelection: Equatable, Sendable {
    let sequence: CompanionVideoSequence
    let trigger: String
    let usedFallbackTrigger: Bool
}
