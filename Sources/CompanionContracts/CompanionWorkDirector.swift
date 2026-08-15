import Foundation

public enum CompanionCelebrationTier: String, Equatable, Sendable {
    case quiet
    case warm
    case playful
    case signature
}

public struct CompanionCompletionContext: Equatable, Sendable {
    public let duration: TimeInterval
    public let completionCountToday: Int
    public let recoveredAfterFailure: Bool
    public let tier: CompanionCelebrationTier

    public init(
        duration: TimeInterval,
        completionCountToday: Int,
        recoveredAfterFailure: Bool,
        tier: CompanionCelebrationTier
    ) {
        self.duration = duration
        self.completionCountToday = completionCountToday
        self.recoveredAfterFailure = recoveredAfterFailure
        self.tier = tier
    }
}

public enum CompanionWorkDecision: Equatable, Sendable {
    case focusStarted
    case focusProgress(elapsed: TimeInterval)
    case longRunning(elapsed: TimeInterval)
    case completed(CompanionCompletionContext)
    case failed
    case cancelled
    case responseReady
    case integrationHealthy
    case integrationDisconnected
    case none
}

/// A privacy-minimal, local state machine that turns lifecycle events into a
/// coherent work arc. It only retains opaque task references in memory and persists
/// the content-free daily counters represented by `CompanionWorkdayStateV1`.
public struct CompanionWorkDirector: Sendable {
    private var startedAtByTaskKey: [String: Date] = [:]
    private var lastFailureAt: Date?
    private let calendar: Calendar

    public private(set) var workdayState: CompanionWorkdayStateV1

    public init(
        workdayState: CompanionWorkdayStateV1 = CompanionWorkdayStateV1(),
        calendar: Calendar = .current
    ) {
        self.workdayState = workdayState
        self.lastFailureAt = workdayState.lastFailureAt
        self.calendar = calendar
    }

    public var hasActiveWork: Bool {
        !startedAtByTaskKey.isEmpty
    }

    @discardableResult
    public mutating func refreshDay(at date: Date) -> CompanionWorkdayStateV1 {
        workdayState.rollForward(
            to: CompanionWorkdayStateV1.dayIdentifier(for: date, calendar: calendar)
        )
        lastFailureAt = workdayState.lastFailureAt
        return workdayState
    }

    @discardableResult
    public mutating func resetWorkday(at date: Date) -> CompanionWorkdayStateV1 {
        workdayState = CompanionWorkdayStateV1(
            dayIdentifier: CompanionWorkdayStateV1.dayIdentifier(
                for: date,
                calendar: calendar
            )
        )
        lastFailureAt = nil
        return workdayState
    }

    public mutating func consume(
        type: CompanionEventType,
        eventID: String,
        taskRef: String?,
        duration: TimeInterval,
        occurredAt: Date
    ) -> CompanionWorkDecision {
        refreshDay(at: occurredAt)
        let taskKey = normalizedTaskKey(taskRef: taskRef, eventID: eventID)

        switch type {
        case .taskStarted:
            if let startedAt = startedAtByTaskKey[taskKey] {
                return .focusProgress(
                    elapsed: max(0, occurredAt.timeIntervalSince(startedAt))
                )
            }
            startedAtByTaskKey[taskKey] = occurredAt
            workdayState.recordStarted(at: occurredAt)
            return .focusStarted

        case .taskProgress:
            return .focusProgress(
                elapsed: elapsed(
                    taskKey: taskKey,
                    explicitDuration: duration,
                    at: occurredAt
                )
            )

        case .taskLongRunning:
            return .longRunning(
                elapsed: elapsed(
                    taskKey: taskKey,
                    explicitDuration: duration,
                    at: occurredAt
                )
            )

        case .taskCompleted:
            let effectiveDuration = elapsed(
                taskKey: taskKey,
                explicitDuration: duration,
                at: occurredAt
            )
            startedAtByTaskKey.removeValue(forKey: taskKey)

            let recovered = lastFailureAt.map {
                occurredAt.timeIntervalSince($0) <= 30 * 60
                    && occurredAt >= $0
            } ?? false
            if recovered {
                lastFailureAt = nil
            }
            workdayState.recordCompletion(
                duration: effectiveDuration,
                recoveredAfterFailure: recovered,
                at: occurredAt
            )
            if !recovered, lastFailureAt == nil {
                workdayState.clearFailureMemory()
            }

            let completionCount = Int(
                min(workdayState.completedCount, UInt64(Int.max))
            )
            let context = CompanionCompletionContext(
                duration: effectiveDuration,
                completionCountToday: completionCount,
                recoveredAfterFailure: recovered,
                tier: celebrationTier(
                    duration: effectiveDuration,
                    completionCount: completionCount,
                    recovered: recovered
                )
            )
            return .completed(context)

        case .taskFailed:
            let effectiveDuration = elapsed(
                taskKey: taskKey,
                explicitDuration: duration,
                at: occurredAt
            )
            startedAtByTaskKey.removeValue(forKey: taskKey)
            lastFailureAt = occurredAt
            workdayState.recordFailure(duration: effectiveDuration, at: occurredAt)
            return .failed

        case .taskCancelled:
            let effectiveDuration = elapsed(
                taskKey: taskKey,
                explicitDuration: duration,
                at: occurredAt
            )
            startedAtByTaskKey.removeValue(forKey: taskKey)
            workdayState.recordCancellation(
                duration: effectiveDuration,
                at: occurredAt
            )
            return .cancelled

        case .responseReady:
            workdayState.recordResponseReady(at: occurredAt)
            return .responseReady

        case .integrationHealth:
            return .integrationHealthy

        case .integrationDisconnected:
            return .integrationDisconnected
        }
    }

    private func normalizedTaskKey(taskRef: String?, eventID: String) -> String {
        if let taskRef, !taskRef.isEmpty {
            return "task:\(taskRef)"
        }
        // Upstream sources without a task reference can only describe one
        // anonymous foreground task reliably. Do not persist the event ID.
        _ = eventID
        return "task:anonymous"
    }

    private func elapsed(
        taskKey: String,
        explicitDuration: TimeInterval,
        at date: Date
    ) -> TimeInterval {
        if explicitDuration.isFinite, explicitDuration > 0 {
            return explicitDuration
        }
        guard let startedAt = startedAtByTaskKey[taskKey] else {
            return 0
        }
        return max(0, date.timeIntervalSince(startedAt))
    }

    private func celebrationTier(
        duration: TimeInterval,
        completionCount: Int,
        recovered: Bool
    ) -> CompanionCelebrationTier {
        if recovered || duration >= 45 * 60 || completionCount.isMultiple(of: 3) {
            return .signature
        }
        if duration >= 10 * 60 || completionCount >= 2 {
            return .playful
        }
        if duration > 0 {
            return .warm
        }
        return .quiet
    }
}
