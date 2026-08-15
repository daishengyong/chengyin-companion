import CompanionContracts
import Foundation

/// Privacy-minimal work signal accepted by the shared workday coordinator.
/// It carries no task title, prompt, path, code or upstream response body.
struct CodexTaskSignal: Sendable, Equatable {
    typealias Origin = CompanionWorkdaySignalOrigin

    let id: String
    let duration: TimeInterval
    let type: CompanionEventType
    let taskRef: String?
    let outcome: CompanionEventOutcome?
    let occurredAt: Date
    let origin: Origin

    init(
        id: String,
        duration: TimeInterval = 0,
        type: CompanionEventType,
        taskRef: String? = nil,
        outcome: CompanionEventOutcome? = nil,
        occurredAt: Date = Date(),
        origin: Origin = .explicitProtocol
    ) {
        self.id = id
        self.duration = duration
        self.type = type
        self.taskRef = taskRef
        self.outcome = outcome
        self.occurredAt = occurredAt
        self.origin = origin
    }

    var isTrustedTaskCompletion: Bool {
        effectiveWorkdayEventType == .taskCompleted
    }

    var effectiveWorkdayEventType: CompanionEventType {
        CompanionWorkdaySignalTrustPolicy.effectiveType(
            requestedType: type,
            outcome: outcome,
            origin: origin
        )
    }
}

/// Decodes one bounded protocol envelope and projects only privacy-safe facts.
/// Producer classification and terminal trust remain deterministic Core rules.
enum CodexProtocolEventExtractor {
    static let maximumRetainedDurationMs: Int64 = 30 * 24 * 60 * 60 * 1_000

    static func signal(
        from data: Data,
        startedAt: Date,
        now: Date = Date()
    ) -> CodexTaskSignal? {
        guard let event = try? CompanionEventCodec.decode(data, now: now) else {
            return nil
        }
        return signal(from: event, startedAt: startedAt)
    }

    static func signal(
        from event: CompanionEvent,
        startedAt: Date
    ) -> CodexTaskSignal? {
        guard event.occurredAt >= startedAt.addingTimeInterval(-3) else {
            return nil
        }

        let origin = CompanionWorkdaySignalSourcePolicy.origin(
            source: event.source,
            sourceVersion: event.sourceVersion
        )
        let type = CompanionWorkdaySignalTrustPolicy.effectiveType(
            requestedType: event.type,
            outcome: event.outcome,
            origin: origin
        )
        let durationMs = event.durationMs.flatMap {
            $0 <= maximumRetainedDurationMs ? $0 : nil
        }
        let taskRef: String?
        switch type {
        case .integrationHealth, .integrationDisconnected:
            taskRef = nil
        default:
            taskRef = privacySafeTaskReference(event.taskRef)
        }

        return CodexTaskSignal(
            id: event.eventId,
            duration: Double(durationMs ?? 0) / 1_000,
            type: type,
            taskRef: taskRef,
            outcome: event.outcome,
            occurredAt: event.occurredAt,
            origin: origin
        )
    }

    private static func privacySafeTaskReference(_ value: String?) -> String? {
        guard
            let value,
            !value.isEmpty,
            value.count <= 256,
            value.unicodeScalars.allSatisfy(isAllowedOpaqueReferenceScalar)
        else {
            return nil
        }
        return value
    }

    private static func isAllowedOpaqueReferenceScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 48...57, 65...90, 97...122:
            true
        case 45, 46, 95:
            true
        default:
            false
        }
    }
}
