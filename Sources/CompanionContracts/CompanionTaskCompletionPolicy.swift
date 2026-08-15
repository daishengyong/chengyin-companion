import Foundation

/// The direct gesture used to answer a trusted task-completion celebration.
///
/// It deliberately contains no AppKit gesture event, pointer position or user
/// work content, so every UI surface can share the same bounded reply contract.
public enum CompanionCompletionReplyGesture: String, CaseIterable, Sendable {
    case singleTap
    case doubleTap
    case longPress
    case drag
}

/// Content-free audiovisual beats understood by the App presentation adapter.
public enum CompanionTaskCompletionRewardBeat: String, CaseIterable, Sendable {
    case clap
    case cheer
    case jump
    case twirl
    case heart
    case kiss
}

/// Localization intent for the spoken/visible completion line.
public enum CompanionTaskCompletionCopyIntent: String, CaseIterable, Sendable {
    case recovered
    case quiet
    case warm
    case playful
    case signature
}

public struct CompanionTaskCompletionCelebrationPlan: Equatable, Sendable {
    public let copy: CompanionTaskCompletionCopyIntent
    public let rewardBeat: CompanionTaskCompletionRewardBeat

    public init(
        copy: CompanionTaskCompletionCopyIntent,
        rewardBeat: CompanionTaskCompletionRewardBeat
    ) {
        self.copy = copy
        self.rewardBeat = rewardBeat
    }
}

public struct CompanionCompletionReplyPlan: Equatable, Sendable {
    /// Opaque bounded relationship key. It never contains task text or paths.
    public let relationshipKey: String
    public let bond: UInt64
    public let chemistry: Int
    public let rewardBeat: CompanionTaskCompletionRewardBeat

    public init(
        relationshipKey: String,
        bond: UInt64,
        chemistry: Int,
        rewardBeat: CompanionTaskCompletionRewardBeat
    ) {
        self.relationshipKey = relationshipKey
        self.bond = bond
        self.chemistry = chemistry
        self.rewardBeat = rewardBeat
    }
}

/// Pure task-completion celebration and reply policy.
///
/// The policy accepts only a semantic completion context, a relationship-tone
/// ceiling and an injected variation. It does not read prompts, titles, code,
/// files, clocks, preferences or media and it creates no persistence side effect.
public enum CompanionTaskCompletionPolicy {
    public static func celebration(
        tier: CompanionCelebrationTier,
        recoveredAfterFailure: Bool,
        allowsRomanticGestures: Bool,
        variation: UInt64
    ) -> CompanionTaskCompletionCelebrationPlan {
        let candidates = rewardCandidates(
            for: tier,
            allowsRomanticGestures: allowsRomanticGestures
        )
        let selected = candidates[Int(variation % UInt64(candidates.count))]
        return CompanionTaskCompletionCelebrationPlan(
            copy: recoveredAfterFailure ? .recovered : copyIntent(for: tier),
            rewardBeat: selected
        )
    }

    public static func reply(
        to gesture: CompanionCompletionReplyGesture,
        allowsRomanticGestures: Bool
    ) -> CompanionCompletionReplyPlan {
        let beat: CompanionTaskCompletionRewardBeat
        switch gesture {
        case .singleTap:
            beat = allowsRomanticGestures ? .heart : .clap
        case .doubleTap:
            beat = allowsRomanticGestures ? .kiss : .twirl
        case .longPress:
            beat = allowsRomanticGestures ? .kiss : .heart
        case .drag:
            beat = .twirl
        }
        return CompanionCompletionReplyPlan(
            relationshipKey: "reply.\(gesture.rawValue)",
            bond: 2,
            chemistry: gesture == .longPress ? 2 : 1,
            rewardBeat: beat
        )
    }

    private static func copyIntent(
        for tier: CompanionCelebrationTier
    ) -> CompanionTaskCompletionCopyIntent {
        switch tier {
        case .quiet: .quiet
        case .warm: .warm
        case .playful: .playful
        case .signature: .signature
        }
    }

    private static func rewardCandidates(
        for tier: CompanionCelebrationTier,
        allowsRomanticGestures: Bool
    ) -> [CompanionTaskCompletionRewardBeat] {
        switch tier {
        case .quiet:
            [.clap]
        case .warm:
            [.cheer]
        case .playful:
            [.jump, .twirl, .clap]
        case .signature where allowsRomanticGestures:
            [.heart, .kiss, .twirl]
        case .signature:
            [.jump, .cheer, .twirl]
        }
    }
}
