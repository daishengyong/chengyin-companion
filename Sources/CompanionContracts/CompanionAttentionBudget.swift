import Foundation

public enum CompanionAttentionKind: String, Equatable, Sendable {
    case userInitiated
    case taskTerminal
    case responseReady
    case lifestyleCare
    case ambientPresence
}

public enum CompanionAttentionSilenceReason: String, Equatable, Sendable {
    case quietHours
    case presentationBusy
    case recentUserInteraction
    case sameKindCooldown
    case hourlyBudgetReached
}

public enum CompanionAttentionDecision: Equatable, Sendable {
    case present
    case ambientOnly(reason: CompanionAttentionSilenceReason)
    case suppress(reason: CompanionAttentionSilenceReason)
}

public struct CompanionAttentionContext: Equatable, Sendable {
    public let now: Date
    public let isPresentationBusy: Bool
    public let isQuietHours: Bool

    public init(
        now: Date,
        isPresentationBusy: Bool,
        isQuietHours: Bool
    ) {
        self.now = now
        self.isPresentationBusy = isPresentationBusy
        self.isQuietHours = isQuietHours
    }
}

public struct CompanionAttentionPolicy: Equatable, Sendable {
    public var postUserInteractionSilence: TimeInterval
    public var responseReadyCooldown: TimeInterval
    public var responseReadyLimitPerHour: Int
    public var proactiveLimitPerHour: Int

    public init(
        postUserInteractionSilence: TimeInterval = 45,
        responseReadyCooldown: TimeInterval = 2 * 60,
        responseReadyLimitPerHour: Int = 3,
        proactiveLimitPerHour: Int = 4
    ) {
        self.postUserInteractionSilence = min(
            max(0, postUserInteractionSilence),
            5 * 60
        )
        self.responseReadyCooldown = max(0, responseReadyCooldown)
        self.responseReadyLimitPerHour = max(0, responseReadyLimitPerHour)
        self.proactiveLimitPerHour = max(0, proactiveLimitPerHour)
    }
}

/// A session-local interruption gate. It limits full audiovisual interruptions while
/// keeping trusted task-terminal events and direct user input reliable.
///
/// The gate stores only timestamps and attention classes. It has no task identifiers,
/// content, streak, score, commerce or relationship penalty state.
public struct CompanionAttentionBudget: Sendable {
    private struct Presentation: Sendable {
        let kind: CompanionAttentionKind
        let date: Date
    }

    public var policy: CompanionAttentionPolicy
    private var recentPresentations: [Presentation] = []

    public init(policy: CompanionAttentionPolicy = CompanionAttentionPolicy()) {
        self.policy = policy
    }

    public mutating func decide(
        for kind: CompanionAttentionKind,
        context: CompanionAttentionContext
    ) -> CompanionAttentionDecision {
        prune(at: context.now)

        switch kind {
        case .userInitiated, .taskTerminal:
            record(kind, at: context.now)
            return .present

        case .responseReady:
            if context.isQuietHours {
                return .ambientOnly(reason: .quietHours)
            }
            if context.isPresentationBusy {
                return .ambientOnly(reason: .presentationBusy)
            }
            if isInsidePostUserInteractionSilence(at: context.now) {
                return .ambientOnly(reason: .recentUserInteraction)
            }
            if let last = recentPresentations.last(where: { $0.kind == .responseReady }),
               context.now.timeIntervalSince(last.date) < policy.responseReadyCooldown {
                return .ambientOnly(reason: .sameKindCooldown)
            }
            let responseCount = recentPresentations.filter {
                $0.kind == .responseReady
            }.count
            if responseCount >= policy.responseReadyLimitPerHour
                || proactiveCount >= policy.proactiveLimitPerHour {
                return .ambientOnly(reason: .hourlyBudgetReached)
            }
            record(kind, at: context.now)
            return .present

        case .lifestyleCare, .ambientPresence:
            if context.isQuietHours {
                return .suppress(reason: .quietHours)
            }
            if context.isPresentationBusy {
                return .suppress(reason: .presentationBusy)
            }
            if isInsidePostUserInteractionSilence(at: context.now) {
                return .suppress(reason: .recentUserInteraction)
            }
            if proactiveCount >= policy.proactiveLimitPerHour {
                return .suppress(reason: .hourlyBudgetReached)
            }
            record(kind, at: context.now)
            return .present
        }
    }

    private var proactiveCount: Int {
        recentPresentations.filter {
            $0.kind == .responseReady
                || $0.kind == .lifestyleCare
                || $0.kind == .ambientPresence
        }.count
    }

    private func isInsidePostUserInteractionSilence(at now: Date) -> Bool {
        guard policy.postUserInteractionSilence > 0,
              let lastUserInteraction = recentPresentations.last(where: {
                  $0.kind == .userInitiated
              })
        else { return false }
        let age = now.timeIntervalSince(lastUserInteraction.date)
        return age.isFinite
            && age >= 0
            && age < policy.postUserInteractionSilence
    }

    private mutating func prune(at now: Date) {
        recentPresentations.removeAll {
            let age = now.timeIntervalSince($0.date)
            return !age.isFinite || age < 0 || age >= 60 * 60
        }
        if recentPresentations.count > 64 {
            recentPresentations.removeFirst(recentPresentations.count - 64)
        }
    }

    private mutating func record(_ kind: CompanionAttentionKind, at date: Date) {
        recentPresentations.append(Presentation(kind: kind, date: date))
    }
}
