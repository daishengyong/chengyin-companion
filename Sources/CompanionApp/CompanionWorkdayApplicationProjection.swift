import CompanionContracts
import Foundation

enum CompanionWorkdayApplicationEvent: Equatable {
    case taskComplete(CompanionCompletionContext)
    case taskFailed
    case responseReady
}

struct CompanionWorkdayRelationshipApplication: Equatable {
    let momentID: String
    let bond: UInt64
    let chemistry: Int
    let primaryMementoID: String?
    let additionalMementoIDs: [String]
}

struct CompanionWorkdayApplicationPlan: Equatable {
    let visual: CompanionCodexVisualState?
    let mood: PetMood?
    let status: String?
    let contentCue: CompanionWorkdayContentCue?
    let event: CompanionWorkdayApplicationEvent?
    let relationship: CompanionWorkdayRelationshipApplication?
}

/// Converts one Core workday presentation into values the App may execute.
/// This is deliberately side-effect free: it is the only place where a
/// semantic workday event becomes an App completion/failure/reply event.
/// Relationship rewards and a completed visual are accepted only alongside
/// an explicit trusted completion event.
enum CompanionWorkdayApplicationProjection {
    static func project(
        _ presentation: CompanionWorkdayPresentationPlan
    ) -> CompanionWorkdayApplicationPlan {
        let event = applicationEvent(for: presentation.event)
        let isCompletion: Bool
        if case .taskComplete = event {
            isCompletion = true
        } else {
            isCompletion = false
        }

        return CompanionWorkdayApplicationPlan(
            visual: projectedVisual(
                presentation.visual,
                allowsCompleted: isCompletion
            ),
            mood: presentation.mood?.appMood,
            status: presentation.status.map {
                CompanionWorkdayPresentationCopy.status(for: $0)
            },
            contentCue: presentation.contentCue,
            event: event,
            relationship: isCompletion
                ? presentation.relationshipReward.map(relationshipApplication)
                : nil
        )
    }

    private static func applicationEvent(
        for event: CompanionWorkdayEventIntent?
    ) -> CompanionWorkdayApplicationEvent? {
        switch event {
        case let .taskComplete(context): .taskComplete(context)
        case .taskFailed: .taskFailed
        case .responseReady: .responseReady
        case .none: nil
        }
    }

    private static func projectedVisual(
        _ visual: CompanionWorkdayVisualIntent?,
        allowsCompleted: Bool
    ) -> CompanionCodexVisualState? {
        guard visual != .completed || allowsCompleted else { return nil }
        return visual?.appVisualState
    }

    private static func relationshipApplication(
        _ reward: CompanionWorkdayRelationshipReward
    ) -> CompanionWorkdayRelationshipApplication {
        let firstCompletion = reward.milestones.first {
            $0 == .firstCompletion
        }
        return CompanionWorkdayRelationshipApplication(
            momentID: "task.completed",
            bond: reward.bond,
            chemistry: reward.chemistry,
            primaryMementoID: firstCompletion?.mementoID,
            additionalMementoIDs: reward.milestones.compactMap {
                $0 == .firstCompletion ? nil : $0.mementoID
            }
        )
    }
}
