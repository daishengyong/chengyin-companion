#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Foundation

enum CompanionWorkdayAdapterError: Error, CompanionErrorCoding, Sendable {
    case persistenceFailed
    case resetFailed

    var companionErrorCode: String {
        switch self {
        case .persistenceFailed:
            "WORKDAY_PERSISTENCE_FAILED"
        case .resetFailed:
            "WORKDAY_RESET_FAILED"
        }
    }
}

struct CompanionWorkdayMutationReceipt: Sendable {
    let decision: CompanionWorkDecision
    let persistenceError: CompanionWorkdayAdapterError?
}

/// Main-actor bridge for the privacy-minimal shared-workday state machine.
/// Lifecycle presentation remains live if local persistence fails, while the
/// receipt makes that failure explicit instead of pretending the snapshot was
/// durably saved.
@MainActor
final class CompanionWorkdayAdapter {
    private let store: CompanionWorkdayStateStore
    private var director: CompanionWorkDirector

    private(set) var state: CompanionWorkdayStateV1
    private(set) var recoverySource: CompanionWorkdayStateRecoverySource

    init(
        store: CompanionWorkdayStateStore = CompanionWorkdayStateStore(),
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.store = store
        let result = store.loadWithRecovery(
            dayIdentifier: CompanionWorkdayStateV1.dayIdentifier(
                for: now,
                calendar: calendar
            )
        )
        state = result.state
        recoverySource = result.recoverySource
        director = CompanionWorkDirector(
            workdayState: result.state,
            calendar: calendar
        )
    }

    var hasActiveWork: Bool {
        director.hasActiveWork
    }

    /// Returns a privacy-safe error only when the day changed but the new clean
    /// snapshot could not be persisted. No error means either no change or a
    /// successful durable rollover.
    func refresh(at now: Date) -> CompanionWorkdayAdapterError? {
        let previous = director.workdayState
        _ = director.refreshDay(at: now)
        guard director.workdayState != previous else {
            state = director.workdayState
            return nil
        }
        return persistDirectorState()
    }

    func consume(
        type: CompanionEventType,
        eventID: String,
        taskRef: String?,
        duration: TimeInterval,
        occurredAt: Date
    ) -> CompanionWorkdayMutationReceipt {
        let decision = director.consume(
            type: type,
            eventID: eventID,
            taskRef: taskRef,
            duration: duration,
            occurredAt: occurredAt
        )
        return CompanionWorkdayMutationReceipt(
            decision: decision,
            persistenceError: persistDirectorState()
        )
    }

    func reset(at now: Date, calendar: Calendar = .current) throws {
        let dayIdentifier = CompanionWorkdayStateV1.dayIdentifier(
            for: now,
            calendar: calendar
        )
        do {
            let resetState = try store.reset(dayIdentifier: dayIdentifier)
            _ = director.resetWorkday(at: now)
            state = resetState
            recoverySource = .primary
        } catch {
            throw CompanionWorkdayAdapterError.resetFailed
        }
    }

    private func persistDirectorState() -> CompanionWorkdayAdapterError? {
        state = director.workdayState
        do {
            try store.save(state)
            recoverySource = .primary
            return nil
        } catch {
            return .persistenceFailed
        }
    }
}
