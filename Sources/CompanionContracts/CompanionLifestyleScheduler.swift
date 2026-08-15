import Foundation

public enum CompanionLifestyleReminderKind: String, Codable, CaseIterable, Hashable, Sendable {
    case morningGreeting
    case hydration
    case sedentaryMovement
    case eyeRest
    case focusEncouragement
    case hourlyTimeAnnouncement
    case halfHourlyTimeAnnouncement
    case lunch
    case eveningWindDown
    case lateNightRest

    var isHealthReminder: Bool {
        switch self {
        case .hydration, .sedentaryMovement, .eyeRest:
            true
        default:
            false
        }
    }

    fileprivate var stableID: UInt64 {
        UInt64(Self.allCases.firstIndex(of: self) ?? 0) + 1
    }
}

public struct CompanionLifestyleReminderOccurrence: Codable, Equatable, Sendable {
    public let kind: CompanionLifestyleReminderKind
    public let date: Date

    public init(kind: CompanionLifestyleReminderKind, date: Date) {
        self.kind = kind
        self.date = date
    }
}

/// A local wall-clock interval represented as minutes after midnight.
/// Equal start and end values mean quiet hours are disabled, not all day.
public struct CompanionLifestyleQuietHours: Equatable, Sendable {
    public let startMinute: Int
    public let endMinute: Int

    public init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.startMinute = Self.minuteOfDay(hour: startHour, minute: startMinute)
        self.endMinute = Self.minuteOfDay(hour: endHour, minute: endMinute)
    }

    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        guard startMinute != endMinute else {
            return false
        }
        let minute = calendar.component(.hour, from: date) * 60
            + calendar.component(.minute, from: date)
        if startMinute < endMinute {
            return minute >= startMinute && minute < endMinute
        }
        return minute >= startMinute || minute < endMinute
    }

    private static func minuteOfDay(hour: Int, minute: Int) -> Int {
        min(max(hour, 0), 23) * 60 + min(max(minute, 0), 59)
    }
}

public enum CompanionLifestyleActivityState: Equatable, Sendable {
    case available
    case focusedWork(startedAt: Date)
    case mediaPlayback
    case gameplay
}

public struct CompanionLifestyleSchedulerContext: Equatable, Sendable {
    public let now: Date
    public let appSessionStart: Date
    public let lastUserInteraction: Date?
    public let lastReminder: CompanionLifestyleReminderOccurrence?
    public let lastReminderByKind: [CompanionLifestyleReminderKind: Date]
    public let lastMeaningfulActivity: Date?
    public let quietHours: CompanionLifestyleQuietHours?
    public let enabledKinds: Set<CompanionLifestyleReminderKind>
    public let activityState: CompanionLifestyleActivityState
    public let dailyCounts: [CompanionLifestyleReminderKind: Int]

    public init(
        now: Date,
        appSessionStart: Date,
        lastUserInteraction: Date? = nil,
        lastReminder: CompanionLifestyleReminderOccurrence? = nil,
        lastReminderByKind: [CompanionLifestyleReminderKind: Date] = [:],
        lastMeaningfulActivity: Date? = nil,
        quietHours: CompanionLifestyleQuietHours? = nil,
        enabledKinds: Set<CompanionLifestyleReminderKind> = Set(
            CompanionLifestyleReminderKind.allCases
        ),
        activityState: CompanionLifestyleActivityState = .available,
        dailyCounts: [CompanionLifestyleReminderKind: Int] = [:]
    ) {
        self.now = now
        self.appSessionStart = appSessionStart
        self.lastUserInteraction = lastUserInteraction
        self.lastReminder = lastReminder
        self.lastReminderByKind = lastReminderByKind
        self.lastMeaningfulActivity = lastMeaningfulActivity
        self.quietHours = quietHours
        self.enabledKinds = enabledKinds
        self.activityState = activityState
        self.dailyCounts = dailyCounts
    }
}

public enum CompanionLifestyleDeferReason: String, Equatable, Sendable {
    case scheduledTime
    case sessionWarmup
    case recentUserInteraction
    case minimumReminderInterval
    case sameKindCooldown
    case focusedWork
}

public enum CompanionLifestyleSilenceReason: String, Equatable, Sendable {
    case noEnabledReminders
    case quietHours
    case mediaPlayback
    case gameplay
    case dailyLimitsReached
    case narrowTimeWindowBlocked
    case noEligibleReminder
}

public enum CompanionLifestyleSchedulerDecision: Equatable, Sendable {
    case play(kind: CompanionLifestyleReminderKind)
    case `defer`(
        kind: CompanionLifestyleReminderKind,
        until: Date,
        reason: CompanionLifestyleDeferReason
    )
    case silence(reason: CompanionLifestyleSilenceReason)
}

public struct CompanionLifestyleSchedulerPolicy: Equatable, Sendable {
    public var intervalScale: Double = 1
    public var sessionWarmup: TimeInterval = 5 * 60
    public var recentInteractionGrace: TimeInterval = 3 * 60
    public var minimumReminderInterval: TimeInterval = 20 * 60
    public var focusedWorkHealthDeferral: TimeInterval = 10 * 60

    public var dailyLimits: [CompanionLifestyleReminderKind: Int] = [
        .morningGreeting: 1,
        .hydration: 6,
        .sedentaryMovement: 5,
        .eyeRest: 8,
        .focusEncouragement: 4,
        .hourlyTimeAnnouncement: 12,
        .halfHourlyTimeAnnouncement: 12,
        .lunch: 1,
        .eveningWindDown: 1,
        .lateNightRest: 1
    ]

    public var sameKindCooldowns: [CompanionLifestyleReminderKind: TimeInterval] = [
        .morningGreeting: 20 * 60 * 60,
        .hydration: 60 * 60,
        .sedentaryMovement: 75 * 60,
        .eyeRest: 40 * 60,
        .focusEncouragement: 75 * 60,
        .hourlyTimeAnnouncement: 45 * 60,
        .halfHourlyTimeAnnouncement: 45 * 60,
        .lunch: 20 * 60 * 60,
        .eveningWindDown: 18 * 60 * 60,
        .lateNightRest: 18 * 60 * 60
    ]
    public init() {}
}

/// Pure, local lifestyle scheduling. There is no wall-clock lookup, persistence,
/// network, LLM, commerce, streak, score, or penalty state in this model.
public struct CompanionLifestyleScheduler: Sendable {
    public var policy = CompanionLifestyleSchedulerPolicy()
    public var calendar: Calendar

    public init(
        policy: CompanionLifestyleSchedulerPolicy = CompanionLifestyleSchedulerPolicy(),
        calendar: Calendar = .current
    ) {
        self.policy = policy
        self.calendar = calendar
    }

    public func decide(
        context: CompanionLifestyleSchedulerContext,
        randomSeed: UInt64
    ) -> CompanionLifestyleSchedulerDecision {
        guard !context.enabledKinds.isEmpty else {
            return .silence(reason: .noEnabledReminders)
        }

        if context.quietHours?.contains(context.now, calendar: calendar) == true {
            return .silence(reason: .quietHours)
        }

        switch context.activityState {
        case .mediaPlayback:
            return .silence(reason: .mediaPlayback)
        case .gameplay:
            return .silence(reason: .gameplay)
        case .available, .focusedWork:
            break
        }

        let enabledCandidates = makeCandidates(context: context, seed: randomSeed)
            .filter { context.enabledKinds.contains($0.kind) }
        let candidates = enabledCandidates.filter {
                max(0, context.dailyCounts[$0.kind, default: 0])
                    < policy.dailyLimits[$0.kind, default: 0]
            }

        guard !candidates.isEmpty else {
            return .silence(
                reason: enabledCandidates.isEmpty
                    ? .noEligibleReminder
                    : .dailyLimitsReached
            )
        }

        let ordered = candidates.sorted {
            if $0.isDue(at: context.now) != $1.isDue(at: context.now) {
                return $0.isDue(at: context.now)
            }
            if $0.priority != $1.priority {
                return $0.priority > $1.priority
            }
            return $0.dueAt < $1.dueAt
        }

        guard let candidate = ordered.first(where: { $0.isDue(at: context.now) }) else {
            let next = candidates.min {
                if $0.dueAt != $1.dueAt {
                    return $0.dueAt < $1.dueAt
                }
                return $0.priority > $1.priority
            }!
            return .defer(kind: next.kind, until: next.dueAt, reason: .scheduledTime)
        }

        if let warmupEnd = safeFutureDate(
            after: context.appSessionStart,
            interval: policy.sessionWarmup,
            relativeTo: context.now
        ) {
            guard canDefer(candidate, until: warmupEnd) else {
                return .silence(reason: .narrowTimeWindowBlocked)
            }
            return .defer(kind: candidate.kind, until: warmupEnd, reason: .sessionWarmup)
        }

        if let lastInteraction = safePastDate(context.lastUserInteraction, now: context.now) {
            let interactionEnd = lastInteraction.addingTimeInterval(
                policy.recentInteractionGrace
            )
            if interactionEnd > context.now {
                guard canDefer(candidate, until: interactionEnd) else {
                    return .silence(reason: .narrowTimeWindowBlocked)
                }
                return .defer(
                    kind: candidate.kind,
                    until: interactionEnd,
                    reason: .recentUserInteraction
                )
            }
        }

        if let lastReminder = safeOccurrence(context.lastReminder, now: context.now) {
            let intervalEnd = lastReminder.date.addingTimeInterval(
                policy.minimumReminderInterval
            )
            if intervalEnd > context.now {
                guard canDefer(candidate, until: intervalEnd) else {
                    return .silence(reason: .narrowTimeWindowBlocked)
                }
                return .defer(
                    kind: candidate.kind,
                    until: intervalEnd,
                    reason: .minimumReminderInterval
                )
            }

        }

        if let lastSameKind = safePastDate(
            context.lastReminderByKind[candidate.kind],
            now: context.now
        ) {
            let cooldownEnd = lastSameKind.addingTimeInterval(
                policy.sameKindCooldowns[candidate.kind, default: 0]
            )
            if cooldownEnd > context.now {
                guard canDefer(candidate, until: cooldownEnd) else {
                    return .silence(reason: .narrowTimeWindowBlocked)
                }
                return .defer(
                    kind: candidate.kind,
                    until: cooldownEnd,
                    reason: .sameKindCooldown
                )
            }
        }

        if case .focusedWork = context.activityState,
           candidate.kind.isHealthReminder {
            let until = candidate.dueAt.addingTimeInterval(
                policy.focusedWorkHealthDeferral
            )
            if until > context.now {
                return .defer(kind: candidate.kind, until: until, reason: .focusedWork)
            }
        }

        return .play(kind: candidate.kind)
    }

    private func makeCandidates(
        context: CompanionLifestyleSchedulerContext,
        seed: UInt64
    ) -> [Candidate] {
        let now = context.now
        let activityAnchor = latestValidDate(
            context.appSessionStart,
            context.lastMeaningfulActivity,
            notAfter: now
        )
        var result: [Candidate] = []

        appendDailyWindow(
            kind: .morningGreeting,
            startMinute: 7 * 60 + 30,
            targetMinute: 8 * 60,
            endMinute: 10 * 60 + 30,
            jitterMax: 20 * 60,
            priority: 80,
            now: now,
            seed: seed,
            to: &result
        )
        appendInterval(
            kind: .hydration,
            anchor: context.lastReminderByKind[.hydration] ?? activityAnchor,
            interval: scaled(75 * 60),
            jitterMax: 12 * 60,
            priority: 55,
            seed: seed,
            to: &result
        )
        appendInterval(
            kind: .sedentaryMovement,
            anchor: context.lastReminderByKind[.sedentaryMovement] ?? activityAnchor,
            interval: scaled(90 * 60),
            jitterMax: 12 * 60,
            priority: 65,
            seed: seed,
            to: &result
        )
        appendInterval(
            kind: .eyeRest,
            anchor: context.lastReminderByKind[.eyeRest] ?? activityAnchor,
            interval: scaled(50 * 60),
            jitterMax: 8 * 60,
            priority: 60,
            seed: seed,
            to: &result
        )

        if case let .focusedWork(startedAt) = context.activityState {
            let focusAnchor = min(startedAt, now)
            appendInterval(
                kind: .focusEncouragement,
                anchor: context.lastReminderByKind[.focusEncouragement] ?? focusAnchor,
                interval: scaled(75 * 60),
                jitterMax: 10 * 60,
                priority: 45,
                seed: seed,
                to: &result
            )
        }

        appendClockSlot(
            kind: .hourlyTimeAnnouncement,
            minute: 0,
            now: now,
            seed: seed,
            to: &result
        )
        appendClockSlot(
            kind: .halfHourlyTimeAnnouncement,
            minute: 30,
            now: now,
            seed: seed,
            to: &result
        )
        appendDailyWindow(
            kind: .lunch,
            startMinute: 11 * 60 + 30,
            targetMinute: 12 * 60,
            endMinute: 13 * 60 + 30,
            jitterMax: 15 * 60,
            priority: 90,
            now: now,
            seed: seed,
            to: &result
        )
        appendDailyWindow(
            kind: .eveningWindDown,
            startMinute: 17 * 60 + 30,
            targetMinute: 18 * 60,
            endMinute: 20 * 60,
            jitterMax: 20 * 60,
            priority: 75,
            now: now,
            seed: seed,
            to: &result
        )
        appendDailyWindow(
            kind: .lateNightRest,
            startMinute: 22 * 60 + 30,
            targetMinute: 22 * 60 + 30,
            endMinute: 24 * 60,
            jitterMax: 15 * 60,
            priority: 100,
            now: now,
            seed: seed,
            to: &result
        )

        return result
    }

    private func appendInterval(
        kind: CompanionLifestyleReminderKind,
        anchor: Date,
        interval: TimeInterval,
        jitterMax: TimeInterval,
        priority: Int,
        seed: UInt64,
        to candidates: inout [Candidate]
    ) {
        let dueAt = anchor.addingTimeInterval(
            interval + jitter(seed: seed, kind: kind, salt: anchor, max: jitterMax)
        )
        candidates.append(Candidate(kind: kind, dueAt: dueAt, expiresAt: nil, priority: priority))
    }

    private func scaled(_ interval: TimeInterval) -> TimeInterval {
        interval * min(max(policy.intervalScale, 0.5), 2)
    }

    private func appendDailyWindow(
        kind: CompanionLifestyleReminderKind,
        startMinute: Int,
        targetMinute: Int,
        endMinute: Int,
        jitterMax: TimeInterval,
        priority: Int,
        now: Date,
        seed: UInt64,
        to candidates: inout [Candidate]
    ) {
        guard let dayStart = calendar.dateInterval(of: .day, for: now)?.start else {
            return
        }
        let minuteNow = calendar.component(.hour, from: now) * 60
            + calendar.component(.minute, from: now)
        let useToday = minuteNow < endMinute
        let baseDay = useToday
            ? dayStart
            : calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let target = calendar.date(
            byAdding: .minute,
            value: targetMinute,
            to: baseDay
        ) ?? baseDay
        let dueAt = target.addingTimeInterval(
            jitter(seed: seed, kind: kind, salt: baseDay, max: jitterMax)
        )
        let start = calendar.date(
            byAdding: .minute,
            value: startMinute,
            to: baseDay
        ) ?? baseDay
        let end = calendar.date(
            byAdding: .minute,
            value: endMinute,
            to: baseDay
        ) ?? baseDay
        candidates.append(
            Candidate(
                kind: kind,
                dueAt: max(dueAt, start),
                expiresAt: end,
                priority: priority
            )
        )
    }

    private func appendClockSlot(
        kind: CompanionLifestyleReminderKind,
        minute: Int,
        now: Date,
        seed: UInt64,
        to candidates: inout [Candidate]
    ) {
        guard let hourStart = calendar.dateInterval(of: .hour, for: now)?.start else {
            return
        }
        var slot = hourStart.addingTimeInterval(TimeInterval(minute * 60))
        let window: TimeInterval = 90
        let currentWindowEnd = slot.addingTimeInterval(window)
        if now > currentWindowEnd {
            slot = calendar.date(byAdding: .hour, value: 1, to: slot) ?? slot
        }
        let dueAt = slot.addingTimeInterval(
            jitter(seed: seed, kind: kind, salt: slot, max: 45)
        )
        candidates.append(
            Candidate(
                kind: kind,
                dueAt: dueAt,
                expiresAt: slot.addingTimeInterval(window),
                priority: 20
            )
        )
    }

    private func canDefer(_ candidate: Candidate, until date: Date) -> Bool {
        candidate.expiresAt.map { date <= $0 } ?? true
    }

    private func safePastDate(_ date: Date?, now: Date) -> Date? {
        guard let date, date <= now else {
            return nil
        }
        return date
    }

    private func safeOccurrence(
        _ occurrence: CompanionLifestyleReminderOccurrence?,
        now: Date
    ) -> CompanionLifestyleReminderOccurrence? {
        guard let occurrence, occurrence.date <= now else {
            return nil
        }
        return occurrence
    }

    private func safeFutureDate(
        after anchor: Date,
        interval: TimeInterval,
        relativeTo now: Date
    ) -> Date? {
        let safeAnchor = min(anchor, now)
        let result = safeAnchor.addingTimeInterval(max(0, interval))
        return result > now ? result : nil
    }

    private func latestValidDate(_ first: Date, _ second: Date?, notAfter now: Date) -> Date {
        let validFirst = min(first, now)
        guard let second, second <= now else {
            return validFirst
        }
        return max(validFirst, second)
    }

    private func jitter(
        seed: UInt64,
        kind: CompanionLifestyleReminderKind,
        salt: Date,
        max maximum: TimeInterval
    ) -> TimeInterval {
        guard maximum > 0 else {
            return 0
        }
        let saltValue = UInt64(bitPattern: Int64(salt.timeIntervalSince1970.rounded(.down)))
        var value = seed ^ (kind.stableID &* 0x9E3779B97F4A7C15) ^ saltValue
        value &+= 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        let fraction = Double(value >> 11) / Double(UInt64(1) << 53)
        return fraction * maximum
    }
}

private struct Candidate: Equatable, Sendable {
    let kind: CompanionLifestyleReminderKind
    let dueAt: Date
    let expiresAt: Date?
    let priority: Int

    func isDue(at date: Date) -> Bool {
        date >= dueAt && expiresAt.map { date <= $0 } ?? true
    }
}
