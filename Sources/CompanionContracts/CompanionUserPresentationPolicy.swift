import Foundation

public enum CompanionUserPresentationIntent: String, Equatable, Sendable {
    case petInteraction
    case magicWand
    case gameReward
}

/// A side-effect-free window transition plan for direct user interactions.
///
/// Manual play is deliberately stronger than ambient or Codex-driven cues:
/// pet interactions and magic-wand choices expand a pet into the stage, while
/// a completed mini-game earns a fullscreen reward. Every temporary expansion
/// records its origin so the App layer can restore the user's chosen mode.
public struct CompanionUserPresentationPlan: Equatable, Sendable {
    public let targetMode: CompanionPresentationMode?
    public let returnMode: CompanionPresentationMode?

    public init(
        targetMode: CompanionPresentationMode?,
        returnMode: CompanionPresentationMode?
    ) {
        self.targetMode = targetMode
        self.returnMode = returnMode
    }

    public static let unchanged = CompanionUserPresentationPlan(
        targetMode: nil,
        returnMode: nil
    )
}

public struct CompanionUserPresentationPolicy: Sendable {
    public init() {}

    public func plan(
        for intent: CompanionUserPresentationIntent,
        currentMode: CompanionPresentationMode,
        audiovisualEnabled: Bool
    ) -> CompanionUserPresentationPlan {
        guard audiovisualEnabled else {
            return .unchanged
        }

        switch intent {
        case .petInteraction, .magicWand:
            guard currentMode == .pet else {
                return .unchanged
            }
            return CompanionUserPresentationPlan(
                targetMode: .stage,
                returnMode: .pet
            )

        case .gameReward:
            guard currentMode != .fullscreen else {
                return .unchanged
            }
            return CompanionUserPresentationPlan(
                targetMode: .fullscreen,
                returnMode: currentMode
            )
        }
    }
}
