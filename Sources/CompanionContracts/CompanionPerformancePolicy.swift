import Foundation

/// Pure contract for the low-impact rendering path. The app may improve the
/// visuals, but it must not silently re-enable looping media or video
/// experiences while the user has selected reduced dynamic effects.
public struct CompanionPerformancePolicy: Equatable, Sendable {
    public let reducedDynamicEffectsEnabled: Bool
    public let systemReduceMotionEnabled: Bool
    public let requestedPlayback: CompanionPlaybackPreference

    public init(
        reducedDynamicEffectsEnabled: Bool,
        systemReduceMotionEnabled: Bool,
        requestedPlayback: CompanionPlaybackPreference
    ) {
        self.reducedDynamicEffectsEnabled = reducedDynamicEffectsEnabled
        self.systemReduceMotionEnabled = systemReduceMotionEnabled
        self.requestedPlayback = requestedPlayback
    }

    public var effectivePlayback: CompanionPlaybackPreference {
        reducedDynamicEffectsEnabled ? .audioOnly : requestedPlayback
    }

    public var permitsLoopingVideo: Bool {
        !reducedDynamicEffectsEnabled
    }

    public var permitsVideoExperiences: Bool {
        effectivePlayback == .audiovisual
    }

    public var usesAnimatedTransitions: Bool {
        !reducedDynamicEffectsEnabled && !systemReduceMotionEnabled
    }
}
