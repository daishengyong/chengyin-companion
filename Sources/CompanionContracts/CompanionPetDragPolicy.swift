import Foundation

/// Semantic feedback for a completed direct-manipulation gesture.
///
/// The Core contract deliberately carries no copy, media, window or audio type.
/// CompanionApp projects the plan into local effects after the gesture ends.
public enum CompanionPetDragFeedback: String, CaseIterable, Equatable, Sendable {
    case fling
    case dock
    case lift
    case nudge
    case settle
}

public struct CompanionPetDragInput: Equatable, Sendable {
    public let translationX: Double
    public let translationY: Double
    public let velocityX: Double
    public let velocityY: Double
    public let windowMoveObserved: Bool
    public let dockEdge: CompanionWindowDockEdge?

    public init(
        translationX: Double,
        translationY: Double,
        velocityX: Double,
        velocityY: Double,
        windowMoveObserved: Bool,
        dockEdge: CompanionWindowDockEdge?
    ) {
        self.translationX = translationX
        self.translationY = translationY
        self.velocityX = velocityX
        self.velocityY = velocityY
        self.windowMoveObserved = windowMoveObserved
        self.dockEdge = dockEdge
    }
}

public struct CompanionPetDragPosePlan: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let rotation: Double
    public let scale: Double

    public init(x: Double, y: Double, rotation: Double, scale: Double) {
        self.x = x
        self.y = y
        self.rotation = rotation
        self.scale = scale
    }
}

public struct CompanionPetDragPlan: Equatable, Sendable {
    public let feedback: CompanionPetDragFeedback
    public let dockEdge: CompanionWindowDockEdge?
    public let pose: CompanionPetDragPosePlan
    public let poseResetDelay: TimeInterval
    public let relationshipMomentKey: String

    public init(
        feedback: CompanionPetDragFeedback,
        dockEdge: CompanionWindowDockEdge?,
        pose: CompanionPetDragPosePlan,
        poseResetDelay: TimeInterval,
        relationshipMomentKey: String
    ) {
        self.feedback = feedback
        self.dockEdge = dockEdge
        self.pose = pose
        self.poseResetDelay = poseResetDelay
        self.relationshipMomentKey = relationshipMomentKey
    }
}

/// Pure classification and motion plan for drag release.
///
/// Priority is intentional: a fast release remains a fling even if it lands on
/// an edge; a slow dock beats lift; short movement is a nudge; and a moved
/// window settles. Non-finite or extreme pointer values are normalized before
/// geometry is calculated so malformed input cannot escape the bounded pose.
public enum CompanionPetDragPolicy {
    public static let flingSpeedThreshold = 900.0
    public static let movedDistanceThreshold = 24.0
    public static let liftDistanceThreshold = 70.0

    public static func plan(for input: CompanionPetDragInput) -> CompanionPetDragPlan {
        let translationX = bounded(input.translationX)
        let translationY = bounded(input.translationY)
        let velocityX = bounded(input.velocityX)
        let velocityY = bounded(input.velocityY)
        let speed = hypot(velocityX, velocityY)
        let movedWindow = input.windowMoveObserved
            || hypot(translationX, translationY) > movedDistanceThreshold

        let feedback: CompanionPetDragFeedback
        let pose: CompanionPetDragPosePlan
        if speed > flingSpeedThreshold {
            feedback = .fling
            pose = CompanionPetDragPosePlan(
                x: clamp(velocityX * 0.012, minimum: -12, maximum: 12),
                y: 2,
                rotation: velocityX >= 0 ? 13 : -13,
                scale: 1.045
            )
        } else if let edge = input.dockEdge {
            feedback = .dock
            pose = CompanionPetDragPosePlan(
                x: edge == .left ? -5 : (edge == .right ? 5 : 0),
                y: edge == .top ? 5 : 0,
                rotation: edge == .left ? -5 : (edge == .right ? 5 : 0),
                scale: 1.035
            )
        } else if translationY > liftDistanceThreshold {
            feedback = .lift
            pose = CompanionPetDragPosePlan(
                x: 0,
                y: 10,
                rotation: 0,
                scale: 1.06
            )
        } else {
            feedback = movedWindow ? .settle : .nudge
            pose = CompanionPetDragPosePlan(
                x: clamp(translationX * 0.08, minimum: -7, maximum: 7),
                y: 0,
                rotation: clamp(translationX * 0.04, minimum: -5, maximum: 5),
                scale: 1.03
            )
        }

        return CompanionPetDragPlan(
            feedback: feedback,
            dockEdge: input.dockEdge,
            pose: pose,
            poseResetDelay: input.dockEdge == nil ? 0.55 : 1.15,
            relationshipMomentKey: feedback == .fling
                ? "interaction.fling"
                : "interaction.drag"
        )
    }

    private static func bounded(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return clamp(value, minimum: -1_000_000, maximum: 1_000_000)
    }

    private static func clamp(
        _ value: Double,
        minimum: Double,
        maximum: Double
    ) -> Double {
        min(max(value, minimum), maximum)
    }
}
