import Foundation

public enum CodexNotifyMapper {
    /// Maps the documented Codex `notify` payload to the privacy-minimal
    /// Companion Event v1 envelope. The mapper deliberately discards cwd,
    /// input-messages, last-assistant-message, and every unknown field.
    public static func map(_ data: Data, now: Date = Date()) throws -> CompanionEvent? {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.type == "agent-turn-complete" else {
            return nil
        }

        return CompanionEvent(
            source: "codex-notify",
            sourceVersion: nil,
            type: .responseReady,
            taskRef: "opaque-\(UUID().uuidString)",
            occurredAt: now,
            durationMs: nil,
            outcome: nil
        )
    }

    private struct Payload: Decodable {
        let type: String

        private enum CodingKeys: String, CodingKey {
            case type
        }
    }
}
