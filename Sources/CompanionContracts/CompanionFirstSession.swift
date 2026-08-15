import Foundation

/// The one preference asked during the local-first first-session journey.
///
/// This value adjusts only the companion's local rhythm and tone. It is not an
/// account attribute, analytics event or entitlement.
public enum CompanionFirstSessionPreference: String, Codable, CaseIterable, Sendable {
    case workCompanion
    case playfulBreaks
    case gentleCare
}

public enum CompanionFirstSessionLaunchDisposition: Equatable, Sendable {
    case startCleanInstallation
    case preserveExistingInstallation
    case alreadyCompleted
}

public enum CompanionFirstSessionLaunchPolicy {
    public static func disposition(
        storedVersion: Int,
        hasExistingProfile: Bool
    ) -> CompanionFirstSessionLaunchDisposition {
        if storedVersion >= CompanionFirstSessionJourney.contractVersion {
            return .alreadyCompleted
        }
        if storedVersion == -CompanionFirstSessionJourney.contractVersion {
            return .startCleanInstallation
        }
        return hasExistingProfile
            ? .preserveExistingInstallation
            : .startCleanInstallation
    }
}

public enum CompanionFirstSessionStep: String, Codable, Sendable {
    case dormant
    case singleTap
    case doubleTap
    case preference
    case workArc
    case complete
}

public enum CompanionFirstSessionInput: Equatable, Sendable {
    case begin
    case singleTap
    case doubleTap
    case selectPreference(CompanionFirstSessionPreference)
    case workArcCompleted
    case skip
    case replay
}

public enum CompanionFirstSessionEffect: Equatable, Sendable {
    case none
    case presentCoach
    case acknowledgeInteraction
    case applyPreferenceAndRunWorkArc(CompanionFirstSessionPreference)
    case complete
    case skipped
}

public struct CompanionFirstSessionTransition: Equatable, Sendable {
    public let step: CompanionFirstSessionStep
    public let effect: CompanionFirstSessionEffect

    public init(
        step: CompanionFirstSessionStep,
        effect: CompanionFirstSessionEffect
    ) {
        self.step = step
        self.effect = effect
    }
}

/// A deterministic, content-free first-session state machine.
///
/// The journey has no wall-clock, network, payment, identity or task payload.
/// Out-of-order input is ignored so ordinary pet gestures cannot skip a step.
public struct CompanionFirstSessionJourney: Equatable, Sendable {
    public static let contractVersion = 1

    public private(set) var step: CompanionFirstSessionStep
    public private(set) var preference: CompanionFirstSessionPreference?

    public init(
        step: CompanionFirstSessionStep = .dormant,
        preference: CompanionFirstSessionPreference? = nil
    ) {
        self.step = step
        self.preference = preference
    }

    public var isActive: Bool {
        step != .dormant && step != .complete
    }

    @discardableResult
    public mutating func handle(
        _ input: CompanionFirstSessionInput
    ) -> CompanionFirstSessionTransition {
        let effect: CompanionFirstSessionEffect

        switch (step, input) {
        case (.dormant, .begin), (_, .replay):
            step = .singleTap
            preference = nil
            effect = .presentCoach

        case (.singleTap, .singleTap):
            step = .doubleTap
            effect = .acknowledgeInteraction

        case (.doubleTap, .doubleTap):
            step = .preference
            effect = .acknowledgeInteraction

        case let (.preference, .selectPreference(selected)):
            preference = selected
            step = .workArc
            effect = .applyPreferenceAndRunWorkArc(selected)

        case (.workArc, .workArcCompleted):
            step = .complete
            effect = .complete

        case (.singleTap, .skip),
             (.doubleTap, .skip),
             (.preference, .skip),
             (.workArc, .skip):
            step = .complete
            effect = .skipped

        default:
            effect = .none
        }

        return CompanionFirstSessionTransition(step: step, effect: effect)
    }
}
