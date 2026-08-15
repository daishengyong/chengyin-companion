import Foundation

public enum CompanionWorkdayVisualIntent: Equatable, Sendable {
    case idle
    case working
    case completed
}

public enum CompanionWorkdayMoodIntent: Equatable, Sendable {
    case calm
    case focused
    case curious
}

/// Semantic copy intent. Localization stays in CompanionApp.
public enum CompanionWorkdayStatusIntent: Equatable, Sendable {
    case focusStarted
    case focusWorking
    case focusContinued
    case longRunning(minutes: Int)
    case otherWorkContinues
    case cancelled
    case integrationHealthy
    case integrationDisconnected
}

public enum CompanionWorkdayEventIntent: Equatable, Sendable {
    case taskComplete(CompanionCompletionContext)
    case taskFailed
    case responseReady
}

/// Optional pack-authored moments for non-terminal workday transitions.
/// Progress heartbeats deliberately have no cue: they update passive presence
/// without turning frequent telemetry into audiovisual interruptions.
public enum CompanionWorkdayContentCue: String, Equatable, Sendable {
    case taskStarted
    case taskLongRunning
    case taskCancelled
}

public enum CompanionWorkdayMilestone: String, Equatable, Sendable {
    case firstCompletion
    case longFocus
    case threeCompletions
    case recoveredAfterFailure
}

public struct CompanionWorkdayRelationshipReward: Equatable, Sendable {
    public let bond: UInt64
    public let chemistry: Int
    public let milestones: [CompanionWorkdayMilestone]

    public init(
        bond: UInt64,
        chemistry: Int,
        milestones: [CompanionWorkdayMilestone]
    ) {
        self.bond = bond
        self.chemistry = chemistry
        self.milestones = milestones
    }
}

public struct CompanionWorkdayPresentationContext: Equatable, Sendable {
    /// False while direct play, a game, or foreground media owns attention.
    public let allowsPassivePresenceUpdate: Bool
    public let hasActiveWork: Bool
    public let completionReplyWindowActive: Bool

    public init(
        allowsPassivePresenceUpdate: Bool,
        hasActiveWork: Bool,
        completionReplyWindowActive: Bool
    ) {
        self.allowsPassivePresenceUpdate = allowsPassivePresenceUpdate
        self.hasActiveWork = hasActiveWork
        self.completionReplyWindowActive = completionReplyWindowActive
    }
}

public struct CompanionWorkdayPresentationPlan: Equatable, Sendable {
    public let visual: CompanionWorkdayVisualIntent?
    public let mood: CompanionWorkdayMoodIntent?
    public let status: CompanionWorkdayStatusIntent?
    public let contentCue: CompanionWorkdayContentCue?
    public let event: CompanionWorkdayEventIntent?
    public let relationshipReward: CompanionWorkdayRelationshipReward?

    public init(
        visual: CompanionWorkdayVisualIntent? = nil,
        mood: CompanionWorkdayMoodIntent? = nil,
        status: CompanionWorkdayStatusIntent? = nil,
        contentCue: CompanionWorkdayContentCue? = nil,
        event: CompanionWorkdayEventIntent? = nil,
        relationshipReward: CompanionWorkdayRelationshipReward? = nil
    ) {
        self.visual = visual
        self.mood = mood
        self.status = status
        self.contentCue = contentCue
        self.event = event
        self.relationshipReward = relationshipReward
    }
}

/// Projects a content-free lifecycle decision into one coherent presentation
/// plan. Passive status never overwrites a game, direct interaction, or media;
/// trusted terminal events still reach the higher-level experience director.
public enum CompanionWorkdayExperiencePolicy {
    public static func plan(
        for decision: CompanionWorkDecision,
        context: CompanionWorkdayPresentationContext
    ) -> CompanionWorkdayPresentationPlan {
        switch decision {
        case .focusStarted:
            return workingPlan(
                status: .focusStarted,
                contentCue: .taskStarted,
                context: context
            )

        case let .focusProgress(elapsed):
            return workingPlan(
                status: elapsed.isFinite && elapsed >= 60
                    ? .focusContinued
                    : .focusWorking,
                context: context
            )

        case let .longRunning(elapsed):
            return workingPlan(
                status: .longRunning(minutes: boundedMinutes(elapsed)),
                contentCue: .taskLongRunning,
                context: context
            )

        case let .completed(completion):
            return CompanionWorkdayPresentationPlan(
                visual: .completed,
                event: .taskComplete(completion),
                relationshipReward: CompanionWorkdayRelationshipReward(
                    bond: completion.tier == .signature ? 3 : 2,
                    chemistry: 1,
                    milestones: milestones(for: completion)
                )
            )

        case .failed:
            return CompanionWorkdayPresentationPlan(
                visual: context.hasActiveWork ? .working : .idle,
                event: .taskFailed
            )

        case .cancelled:
            return CompanionWorkdayPresentationPlan(
                visual: context.hasActiveWork ? .working : .idle,
                mood: context.allowsPassivePresenceUpdate
                    ? (context.hasActiveWork ? .focused : .calm)
                    : nil,
                status: context.allowsPassivePresenceUpdate
                    ? (context.hasActiveWork ? .otherWorkContinues : .cancelled)
                    : nil,
                contentCue: context.allowsPassivePresenceUpdate
                    ? .taskCancelled
                    : nil
            )

        case .responseReady:
            return CompanionWorkdayPresentationPlan(event: .responseReady)

        case .integrationHealthy:
            return CompanionWorkdayPresentationPlan(
                status: context.allowsPassivePresenceUpdate
                    ? .integrationHealthy
                    : nil
            )

        case .integrationDisconnected:
            return CompanionWorkdayPresentationPlan(
                mood: context.allowsPassivePresenceUpdate ? .curious : nil,
                status: context.allowsPassivePresenceUpdate
                    ? .integrationDisconnected
                    : nil
            )

        case .none:
            return CompanionWorkdayPresentationPlan()
        }
    }

    private static func workingPlan(
        status: CompanionWorkdayStatusIntent,
        contentCue: CompanionWorkdayContentCue? = nil,
        context: CompanionWorkdayPresentationContext
    ) -> CompanionWorkdayPresentationPlan {
        CompanionWorkdayPresentationPlan(
            visual: context.completionReplyWindowActive ? nil : .working,
            mood: context.allowsPassivePresenceUpdate ? .focused : nil,
            status: context.allowsPassivePresenceUpdate ? status : nil,
            contentCue: context.allowsPassivePresenceUpdate ? contentCue : nil
        )
    }

    private static func boundedMinutes(_ elapsed: TimeInterval) -> Int {
        guard elapsed.isFinite, elapsed > 0 else { return 1 }
        let minutes = min(elapsed / 60, Double(Int.max))
        return max(1, Int(minutes))
    }

    private static func milestones(
        for completion: CompanionCompletionContext
    ) -> [CompanionWorkdayMilestone] {
        var result: [CompanionWorkdayMilestone] = []
        if completion.completionCountToday == 1 {
            result.append(.firstCompletion)
        }
        if completion.duration.isFinite, completion.duration >= 10 * 60 {
            result.append(.longFocus)
        }
        if completion.completionCountToday > 0,
           completion.completionCountToday.isMultiple(of: 3) {
            result.append(.threeCompletions)
        }
        if completion.recoveredAfterFailure {
            result.append(.recoveredAfterFailure)
        }
        return result
    }
}
