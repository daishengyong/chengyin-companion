import Foundation

/// Describes how a local lifecycle signal was obtained. It is intentionally
/// content-free and is never persisted in the shared-workday snapshot.
public enum CompanionWorkdaySignalOrigin: String, Equatable, Sendable {
    case companionTerminalEmitter
    case codexAppServerTurn
    case explicitProtocol
    case legacyTurnBoundary
    case runtimeHealth
}

/// Classifies a privacy-minimal event producer without trusting arbitrary
/// values merely because they arrived through the local protocol inbox.
public enum CompanionWorkdaySignalSourcePolicy {
    public static func origin(
        source: String,
        sourceVersion: String?
    ) -> CompanionWorkdaySignalOrigin {
        switch (source, sourceVersion) {
        case ("codex-skill", "terminal-events-v1"):
            .companionTerminalEmitter
        case ("codex-app-server", "turn-events-v1"):
            .codexAppServerTurn
        default:
            .explicitProtocol
        }
    }
}

/// Keeps terminal-state trust in Core so every event adapter applies the same
/// rule. A successful completion must come from the bundled terminal emitter;
/// App Server may report only its documented failure or interruption states.
/// Everything else is a neutral response boundary, never a completion claim.
public enum CompanionWorkdaySignalTrustPolicy {
    public static func effectiveType(
        requestedType: CompanionEventType,
        outcome: CompanionEventOutcome?,
        origin: CompanionWorkdaySignalOrigin
    ) -> CompanionEventType {
        switch (requestedType, outcome, origin) {
        case (.taskCompleted, .success, .companionTerminalEmitter):
            return .taskCompleted
        case (.taskFailed, .failure, .companionTerminalEmitter),
             (.taskFailed, .failure, .codexAppServerTurn),
             (.taskCompleted, .failure, .companionTerminalEmitter):
            return .taskFailed
        case (.taskCancelled, .cancelled, .companionTerminalEmitter),
             (.taskCancelled, .cancelled, .codexAppServerTurn),
             (.taskCompleted, .cancelled, .companionTerminalEmitter):
            return .taskCancelled
        case (.taskCompleted, _, _),
             (.taskFailed, _, _),
             (.taskCancelled, _, _):
            return .responseReady
        default:
            return requestedType
        }
    }
}
