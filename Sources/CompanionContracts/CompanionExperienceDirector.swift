import Foundation

public enum CompanionExperienceSource: String, Equatable, Sendable {
    case userInitiated
    case trustedTaskTerminal
    case responseReady
    case proactiveCare
    case ambientPresence
}

public enum CompanionExperienceDeferralReason: String, Equatable, Sendable {
    case quietHours
    case presentationBusy
    case recentUserInteraction
    case sameKindCooldown
    case hourlyBudgetReached
}

public enum CompanionExperienceDecision: Equatable, Sendable {
    case present
    case ambientOnly(reason: CompanionExperienceDeferralReason)
    case enqueue(reason: CompanionExperienceDeferralReason)
    case deferUntilNextEvaluation(reason: CompanionExperienceDeferralReason)
}

public struct CompanionExperienceContext: Equatable, Sendable {
    public let now: Date
    public let isDirectInteractionActive: Bool
    public let isGameplayActive: Bool
    public let isMediaPlaybackActive: Bool
    public let isSpeaking: Bool
    public let isQuietHours: Bool

    public init(
        now: Date,
        isDirectInteractionActive: Bool,
        isGameplayActive: Bool,
        isMediaPlaybackActive: Bool,
        isSpeaking: Bool,
        isQuietHours: Bool
    ) {
        self.now = now
        self.isDirectInteractionActive = isDirectInteractionActive
        self.isGameplayActive = isGameplayActive
        self.isMediaPlaybackActive = isMediaPlaybackActive
        self.isSpeaking = isSpeaking
        self.isQuietHours = isQuietHours
    }

    public var isPresentationBusy: Bool {
        isDirectInteractionActive
            || isGameplayActive
            || isMediaPlaybackActive
            || isSpeaking
    }
}

/// Arbitrates all companion-initiated presentation lanes before UI code chooses
/// a video, voice line or motion. Trusted terminal events remain reliable, direct
/// interaction remains immediate, and lower-priority cues never pile up behind a
/// user who is already playing or watching something.
///
/// The director is session-local and stores only attention-class timestamps. It
/// never stores task identifiers, prompts, source code, filenames or user text.
public struct CompanionExperienceDirector: Sendable {
    private var attentionBudget: CompanionAttentionBudget

    public init(
        attentionPolicy: CompanionAttentionPolicy = CompanionAttentionPolicy()
    ) {
        attentionBudget = CompanionAttentionBudget(policy: attentionPolicy)
    }

    public mutating func decide(
        for source: CompanionExperienceSource,
        context: CompanionExperienceContext
    ) -> CompanionExperienceDecision {
        switch source {
        case .userInitiated:
            _ = attentionBudget.decide(
                for: .userInitiated,
                context: context.attentionContext
            )
            return .present

        case .trustedTaskTerminal:
            if context.isPresentationBusy {
                return .enqueue(reason: .presentationBusy)
            }
            _ = attentionBudget.decide(
                for: .taskTerminal,
                context: context.attentionContext
            )
            return .present

        case .responseReady:
            return map(
                attentionBudget.decide(
                    for: .responseReady,
                    context: context.attentionContext
                ),
                suppressedBehavior: .ambient
            )

        case .proactiveCare:
            return map(
                attentionBudget.decide(
                    for: .lifestyleCare,
                    context: context.attentionContext
                ),
                suppressedBehavior: .defer
            )

        case .ambientPresence:
            return map(
                attentionBudget.decide(
                    for: .ambientPresence,
                    context: context.attentionContext
                ),
                suppressedBehavior: .defer
            )
        }
    }

    private enum SuppressedBehavior {
        case ambient
        case `defer`
    }

    private func map(
        _ decision: CompanionAttentionDecision,
        suppressedBehavior: SuppressedBehavior
    ) -> CompanionExperienceDecision {
        switch decision {
        case .present:
            return .present
        case let .ambientOnly(reason):
            return .ambientOnly(reason: Self.map(reason))
        case let .suppress(reason):
            switch suppressedBehavior {
            case .ambient:
                return .ambientOnly(reason: Self.map(reason))
            case .defer:
                return .deferUntilNextEvaluation(reason: Self.map(reason))
            }
        }
    }

    private static func map(
        _ reason: CompanionAttentionSilenceReason
    ) -> CompanionExperienceDeferralReason {
        switch reason {
        case .quietHours:
            .quietHours
        case .presentationBusy:
            .presentationBusy
        case .recentUserInteraction:
            .recentUserInteraction
        case .sameKindCooldown:
            .sameKindCooldown
        case .hourlyBudgetReached:
            .hourlyBudgetReached
        }
    }
}

private extension CompanionExperienceContext {
    var attentionContext: CompanionAttentionContext {
        CompanionAttentionContext(
            now: now,
            isPresentationBusy: isPresentationBusy,
            isQuietHours: isQuietHours
        )
    }
}
