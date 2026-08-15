import Foundation

public enum CodexAppServerMapperError: Error, Equatable, Sendable {
    case payloadTooLarge
    case invalidJSON
    case invalidEnvelope
    case invalidStatus
    case invalidDuration

    public var companionErrorCode: String {
        switch self {
        case .payloadTooLarge:
            "APP_SERVER_EVENT_PAYLOAD_TOO_LARGE"
        case .invalidJSON:
            "APP_SERVER_EVENT_INVALID_JSON"
        case .invalidEnvelope:
            "APP_SERVER_EVENT_INVALID_ENVELOPE"
        case .invalidStatus:
            "APP_SERVER_EVENT_INVALID_STATUS"
        case .invalidDuration:
            "APP_SERVER_EVENT_INVALID_DURATION"
        }
    }

    public var recoveryAction: String {
        switch self {
        case .payloadTooLarge:
            "Forward one turn notification at a time and omit item content from the adapter input."
        case .invalidJSON:
            "Provide one complete UTF-8 JSON notification object."
        case .invalidEnvelope:
            "Provide method, params.threadId, params.turn.id, and params.turn.status using the turn-events-v1 contract."
        case .invalidStatus:
            "Use inProgress for turn/started, or completed, failed, or interrupted for turn/completed."
        case .invalidDuration:
            "Remove durationMs or provide milliseconds from zero through 30 days."
        }
    }
}

extension CodexAppServerMapperError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .payloadTooLarge:
            "The App Server notification exceeds the 1 MiB adapter limit."
        case .invalidJSON:
            "The App Server notification is not valid JSON."
        case .invalidEnvelope:
            "The App Server turn notification is missing a required field or has an invalid field type."
        case .invalidStatus:
            "The turn status is not valid for this notification method."
        case .invalidDuration:
            "The turn duration is outside the supported range."
        }
    }
}

public enum CodexAppServerMapper {
    /// This is an ingress bound for a single App Server notification, not the
    /// much smaller Companion Event v1 envelope written to disk.
    public static let maximumPayloadBytes = 1024 * 1024
    public static let maximumDurationMs: Int64 = 30 * 24 * 60 * 60 * 1000

    /// Projects a Codex App Server turn notification into a privacy-minimal
    /// Companion Event. Thread IDs, turn IDs, items, errors, prompts, paths,
    /// assistant content, and all unknown fields are deliberately discarded.
    /// A completed Codex turn means only that a response is ready; it never
    /// proves the user's task objective is complete.
    public static func map(_ data: Data, now: Date = Date()) throws -> CompanionEvent? {
        guard data.count <= maximumPayloadBytes else {
            throw CodexAppServerMapperError.payloadTooLarge
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CodexAppServerMapperError.invalidJSON
        }
        guard object is [String: Any] else {
            throw CodexAppServerMapperError.invalidEnvelope
        }

        let probe: MethodProbe
        do {
            probe = try JSONDecoder().decode(MethodProbe.self, from: data)
        } catch {
            throw CodexAppServerMapperError.invalidEnvelope
        }

        guard probe.method == "turn/started" || probe.method == "turn/completed" else {
            return nil
        }

        let notification: TurnNotification
        do {
            notification = try JSONDecoder().decode(TurnNotification.self, from: data)
        } catch {
            throw CodexAppServerMapperError.invalidEnvelope
        }

        guard Self.isValidOpaqueIdentifier(notification.params.threadId),
              Self.isValidOpaqueIdentifier(notification.params.turn.id) else {
            throw CodexAppServerMapperError.invalidEnvelope
        }

        if let durationMs = notification.params.turn.durationMs,
           !(0...maximumDurationMs).contains(durationMs) {
            throw CodexAppServerMapperError.invalidDuration
        }

        let type: CompanionEventType
        let outcome: CompanionEventOutcome?
        let durationMs: Int64?

        switch (notification.method, notification.params.turn.status) {
        case ("turn/started", "inProgress"):
            type = .taskStarted
            outcome = nil
            durationMs = nil
        case ("turn/completed", "completed"):
            type = .responseReady
            outcome = nil
            durationMs = notification.params.turn.durationMs
        case ("turn/completed", "failed"):
            type = .taskFailed
            outcome = .failure
            durationMs = notification.params.turn.durationMs
        case ("turn/completed", "interrupted"):
            type = .taskCancelled
            outcome = .cancelled
            durationMs = notification.params.turn.durationMs
        default:
            throw CodexAppServerMapperError.invalidStatus
        }

        return CompanionEvent(
            source: "codex-app-server",
            sourceVersion: "turn-events-v1",
            type: type,
            taskRef: nil,
            occurredAt: now,
            durationMs: durationMs,
            outcome: outcome
        )
    }

    private static func isValidOpaqueIdentifier(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= 256
            && !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }

    private struct MethodProbe: Decodable {
        let method: String
    }

    private struct TurnNotification: Decodable {
        let method: String
        let params: Params

        struct Params: Decodable {
            let threadId: String
            let turn: Turn
        }

        struct Turn: Decodable {
            let id: String
            let status: String
            let durationMs: Int64?
        }
    }
}
