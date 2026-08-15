import Foundation

/// Pack-authored return behavior expressed without depending on App media types.
public enum CompanionPresentationContentReturnPolicy: String, Equatable, Sendable {
    case previousMode
    case keepCurrentMode
    case remainExpanded
}

/// A side-effect-free instruction for the App window and compact media surface.
public struct CompanionPresentationDirective: Equatable, Sendable {
    public let targetMode: CompanionPresentationMode?
    public let keepsMediaInPet: Bool
    public let directUserOwnsReturn: Bool

    public init(
        targetMode: CompanionPresentationMode?,
        keepsMediaInPet: Bool = false,
        directUserOwnsReturn: Bool = false
    ) {
        self.targetMode = targetMode
        self.keepsMediaInPet = keepsMediaInPet
        self.directUserOwnsReturn = directUserOwnsReturn
    }
}

/// One presentation lifecycle shared by click, palette, game and automatic cues.
///
/// The type deliberately owns no timers, media or windows. It guarantees that
/// every audiovisual entrance captures a return policy before the App starts
/// playback, and that a generated-media failure can hand off to a local visual
/// fallback without shrinking and reopening the window.
public struct CompanionPresentationLifecycle: Equatable, Sendable {
    private var session: CompanionPresentationSession

    public init(session: CompanionPresentationSession = .init()) {
        self.session = session
    }

    public var directUserOwnsReturn: Bool {
        session.directUserOwnsReturn
    }

    @discardableResult
    public mutating func beginDirectUserPlan(
        _ plan: CompanionUserPresentationPlan
    ) -> CompanionPresentationDirective {
        let targetMode = session.beginDirectUserPlan(plan)
        return CompanionPresentationDirective(
            targetMode: targetMode,
            directUserOwnsReturn: session.directUserOwnsReturn
        )
    }

    /// Automatic care/task cues open a pet into the stage and return it after
    /// the complete response. Already-expanded user windows stay unchanged.
    public mutating func beginAutomaticResponse(
        currentMode: CompanionPresentationMode
    ) -> CompanionPresentationDirective {
        guard currentMode == .pet else {
            return CompanionPresentationDirective(
                targetMode: nil,
                directUserOwnsReturn: session.directUserOwnsReturn
            )
        }
        session.setAutomaticReturnMode(.pet)
        return CompanionPresentationDirective(
            targetMode: .stage,
            directUserOwnsReturn: session.directUserOwnsReturn
        )
    }

    /// Resolves direct ownership and pack return policy before media begins.
    public mutating func beginContentSequence(
        returnPolicy: CompanionPresentationContentReturnPolicy,
        currentMode: CompanionPresentationMode,
        directPlan: CompanionUserPresentationPlan? = nil
    ) -> CompanionPresentationDirective {
        let directTarget = directPlan.flatMap {
            session.beginDirectUserPlan($0)
        }
        if session.directUserOwnsReturn {
            return CompanionPresentationDirective(
                targetMode: directTarget,
                directUserOwnsReturn: true
            )
        }

        switch returnPolicy {
        case .previousMode:
            guard currentMode == .pet else {
                session.setAutomaticReturnMode(nil)
                return CompanionPresentationDirective(targetMode: directTarget)
            }
            session.setAutomaticReturnMode(.pet)
            return CompanionPresentationDirective(targetMode: directTarget ?? .stage)

        case .keepCurrentMode:
            session.setAutomaticReturnMode(nil)
            return CompanionPresentationDirective(
                targetMode: directTarget,
                keepsMediaInPet: currentMode == .pet
            )

        case .remainExpanded:
            session.setAutomaticReturnMode(nil)
            return CompanionPresentationDirective(
                targetMode: directTarget ?? (currentMode == .pet ? .stage : nil)
            )
        }
    }

    /// A game records its pre-game window before starting. On completion this
    /// exact mode replaces the temporary in-game pet/stage return captured by
    /// the fullscreen reward plan.
    public mutating func setDirectReturnMode(
        _ mode: CompanionPresentationMode?
    ) {
        session.setDirectReturnMode(mode)
    }

    @discardableResult
    public mutating func finish(
        continuesIntoFallback: Bool = false
    ) -> CompanionPresentationMode? {
        session.finish(continuesIntoFallback: continuesIntoFallback)
    }

    public mutating func reset() {
        session.reset()
    }
}
