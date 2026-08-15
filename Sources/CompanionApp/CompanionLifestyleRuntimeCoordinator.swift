#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Foundation

enum CompanionLifestyleRuntimeOutcome: Equatable {
    case disabled
    case paused(until: Date)
    case away
    case returnedSettling
    case returnedCoolingDown(until: Date)
    case play(kind: CompanionLifestyleReminderKind)
    case `defer`(kind: CompanionLifestyleReminderKind, until: Date)
    case silence(reason: CompanionLifestyleSilenceReason)
}

struct CompanionLifestyleRuntimeReceipt {
    let outcome: CompanionLifestyleRuntimeOutcome
    let persistenceError: Error?
}

/// Owns the restart-safe lifestyle-care session around the pure Core scheduler.
/// The view model supplies bounded activity facts and performs only the returned
/// presentation side effect; it never reads or mutates the memory payload.
@MainActor
final class CompanionLifestyleRuntimeCoordinator {
    private let memoryAdapter: CompanionLifestyleMemoryAdapter
    private var sessionStartedAt: Date
    private var wasUserRecentlyActive = true
    private var returnedAt: Date?

    convenience init(now: Date = Date()) {
        self.init(
            memoryAdapter: CompanionLifestyleMemoryAdapter(now: now),
            now: now
        )
    }

    init(
        memoryAdapter: CompanionLifestyleMemoryAdapter,
        now: Date
    ) {
        self.memoryAdapter = memoryAdapter
        sessionStartedAt = now
    }

    var pausedUntil: Date? { memoryAdapter.state.pausedUntil }
    var activityAnchor: Date { memoryAdapter.state.activityAnchor }
    var recoverySource: CompanionLifestyleMemoryRecoverySource {
        memoryAdapter.recoverySource
    }

    func evaluate(
        at now: Date,
        remindersEnabled: Bool,
        userRecentlyActive: Bool,
        quietHoursEnabled: Bool,
        timeAnnouncementsEnabled: Bool,
        halfHourlyAnnouncementsEnabled: Bool,
        cadence: CompanionCareCadencePreference,
        activityState: CompanionLifestyleActivityState,
        calendar: Calendar = .current
    ) -> CompanionLifestyleRuntimeReceipt {
        var persistenceError: Error?
        do {
            try memoryAdapter.refresh(at: now, calendar: calendar)
        } catch {
            persistenceError = error
        }

        guard remindersEnabled else {
            return receipt(.disabled, error: persistenceError)
        }

        if let pausedUntil = memoryAdapter.state.pausedUntil,
           pausedUntil > now {
            return receipt(.paused(until: pausedUntil), error: persistenceError)
        }

        guard userRecentlyActive else {
            wasUserRecentlyActive = false
            returnedAt = nil
            return receipt(.away, error: persistenceError)
        }

        if !wasUserRecentlyActive {
            wasUserRecentlyActive = true
            returnedAt = now
            return receipt(.returnedSettling, error: persistenceError)
        }

        if let returnedAt {
            let resumeAt = returnedAt.addingTimeInterval(5 * 60)
            guard now >= resumeAt else {
                return receipt(
                    .returnedCoolingDown(until: resumeAt),
                    error: persistenceError
                )
            }
            self.returnedAt = nil
        }

        let state = memoryAdapter.state
        let context = CompanionLifestyleSchedulerContext(
            now: now,
            appSessionStart: sessionStartedAt,
            lastUserInteraction: returnedAt,
            lastReminder: state.lastReminder,
            lastReminderByKind: state.lastReminderByKind,
            lastMeaningfulActivity: state.activityAnchor,
            quietHours: quietHoursEnabled
                ? CompanionLifestyleQuietHours(
                    startHour: 23,
                    startMinute: 30,
                    endHour: 8,
                    endMinute: 30
                )
                : nil,
            enabledKinds: enabledReminderKinds(
                at: now,
                timeAnnouncementsEnabled: timeAnnouncementsEnabled,
                halfHourlyAnnouncementsEnabled: halfHourlyAnnouncementsEnabled,
                calendar: calendar
            ),
            activityState: activityState,
            dailyCounts: state.dailyCounts
        )
        let scheduler = CompanionLifestyleScheduler(
            policy: schedulerPolicy(for: cadence),
            calendar: calendar
        )

        let outcome: CompanionLifestyleRuntimeOutcome
        switch scheduler.decide(
            context: context,
            randomSeed: state.randomSeed()
        ) {
        case let .play(kind):
            outcome = .play(kind: kind)
        case let .defer(kind, until, _):
            outcome = .defer(kind: kind, until: until)
        case let .silence(reason):
            outcome = .silence(reason: reason)
        }
        return receipt(outcome, error: persistenceError)
    }

    func pause(until: Date, at now: Date) -> Error? {
        update(at: now) { memory in
            memory.setPausedUntil(until, at: now)
        }
    }

    func resume(at now: Date) -> Error? {
        update(at: now) { memory in
            memory.setPausedUntil(nil, at: now)
        }
    }

    func recordDelivered(
        _ kind: CompanionLifestyleReminderKind,
        at date: Date
    ) -> Error? {
        update(at: date) { memory in
            memory.recordReminder(kind, at: date)
        }
    }

    func reset(at now: Date) -> Error? {
        do {
            try memoryAdapter.reset(at: now)
            sessionStartedAt = now
            wasUserRecentlyActive = true
            returnedAt = nil
            return nil
        } catch {
            return error
        }
    }

    private func update(
        at date: Date,
        _ transform: (inout CompanionLifestyleMemoryV1) throws -> Void
    ) -> Error? {
        do {
            try memoryAdapter.update(at: date, transform)
            return nil
        } catch {
            return error
        }
    }

    private func receipt(
        _ outcome: CompanionLifestyleRuntimeOutcome,
        error: Error?
    ) -> CompanionLifestyleRuntimeReceipt {
        CompanionLifestyleRuntimeReceipt(
            outcome: outcome,
            persistenceError: error
        )
    }

    private func schedulerPolicy(
        for cadence: CompanionCareCadencePreference
    ) -> CompanionLifestyleSchedulerPolicy {
        var policy = CompanionLifestyleSchedulerPolicy()
        switch cadence {
        case .gentle:
            policy.intervalScale = 1.3
            policy.minimumReminderInterval = 30 * 60
            policy.dailyLimits[.hydration] = 4
            policy.dailyLimits[.sedentaryMovement] = 3
            policy.dailyLimits[.eyeRest] = 5
            policy.dailyLimits[.focusEncouragement] = 2
        case .standard:
            break
        case .lively:
            policy.intervalScale = 0.72
            policy.minimumReminderInterval = 15 * 60
            policy.sameKindCooldowns[.hydration] = 45 * 60
            policy.sameKindCooldowns[.sedentaryMovement] = 60 * 60
            policy.sameKindCooldowns[.eyeRest] = 30 * 60
            policy.sameKindCooldowns[.focusEncouragement] = 50 * 60
        }
        return policy
    }

    private func enabledReminderKinds(
        at date: Date,
        timeAnnouncementsEnabled: Bool,
        halfHourlyAnnouncementsEnabled: Bool,
        calendar: Calendar
    ) -> Set<CompanionLifestyleReminderKind> {
        var kinds: Set<CompanionLifestyleReminderKind> = [
            .morningGreeting,
            .hydration,
            .sedentaryMovement,
            .eyeRest,
            .focusEncouragement,
            .lunch,
            .eveningWindDown,
            .lateNightRest
        ]
        let hour = calendar.component(.hour, from: date)
        if timeAnnouncementsEnabled, hour.isMultiple(of: 2) {
            kinds.insert(.hourlyTimeAnnouncement)
        }
        if timeAnnouncementsEnabled, halfHourlyAnnouncementsEnabled {
            kinds.insert(.halfHourlyTimeAnnouncement)
        }
        return kinds
    }
}
