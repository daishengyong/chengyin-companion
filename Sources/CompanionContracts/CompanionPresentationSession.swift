import Foundation

public enum CompanionPresentationReturnOwner: String, Equatable, Sendable {
    case automaticExperience
    case directUser
}

/// Side-effect-free ownership for a temporary companion-window expansion.
///
/// A direct click, magic-wand choice or game reward owns its original return
/// mode until the complete audiovisual response (including a local fallback)
/// ends. Pack-authored return policies may shape automatic experiences, but
/// cannot strand a direct interaction in an expanded window.
public struct CompanionPresentationSession: Equatable, Sendable {
    public private(set) var returnMode: CompanionPresentationMode?
    public private(set) var returnOwner: CompanionPresentationReturnOwner?

    public init(
        returnMode: CompanionPresentationMode? = nil,
        returnOwner: CompanionPresentationReturnOwner? = nil
    ) {
        if returnMode == nil {
            self.returnMode = nil
            self.returnOwner = nil
        } else {
            self.returnMode = returnMode
            self.returnOwner = returnOwner ?? .automaticExperience
        }
    }

    public var directUserOwnsReturn: Bool {
        returnMode != nil && returnOwner == .directUser
    }

    /// Starts or continues a direct-play response. An unchanged plan is still
    /// part of the current direct session, so a rapid second click cannot lose
    /// the return mode captured by the first click.
    @discardableResult
    public mutating func beginDirectUserPlan(
        _ plan: CompanionUserPresentationPlan
    ) -> CompanionPresentationMode? {
        if let returnMode = plan.returnMode {
            self.returnMode = returnMode
            returnOwner = .directUser
        }
        return plan.targetMode
    }

    /// Records an automatic reminder/task expansion. Direct-play ownership is
    /// stronger and deliberately survives pack-authored keep/remain policies.
    public mutating func setAutomaticReturnMode(
        _ mode: CompanionPresentationMode?
    ) {
        guard !directUserOwnsReturn else { return }
        returnMode = mode
        returnOwner = mode == nil ? nil : .automaticExperience
    }

    /// Game completion knows the exact pre-game mode and may strengthen an
    /// existing direct reward session without exposing App-layer state.
    public mutating func setDirectReturnMode(
        _ mode: CompanionPresentationMode?
    ) {
        returnMode = mode
        returnOwner = mode == nil ? nil : .directUser
    }

    /// Returns the mode that the App should restore. A failed generated asset
    /// with a local fallback keeps the same expanded session alive, avoiding a
    /// visible shrink-and-reopen flash.
    public mutating func finish(
        continuesIntoFallback: Bool = false
    ) -> CompanionPresentationMode? {
        guard !continuesIntoFallback else { return nil }
        let restoration = returnMode
        reset()
        return restoration
    }

    public mutating func reset() {
        returnMode = nil
        returnOwner = nil
    }
}
