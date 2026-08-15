import Foundation

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    guard condition() else {
        fputs("FAIL  \(message)\n", stderr)
        exit(1)
    }
}

private var utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

private func date(
    _ hour: Int,
    _ minute: Int,
    _ second: Int = 0,
    year: Int = 2026,
    month: Int = 8,
    day: Int = 3
) -> Date {
    utcCalendar.date(
        from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
    )!
}

private func context(
    now: Date,
    sessionStart: Date,
    kind: CompanionLifestyleReminderKind,
    lastUserInteraction: Date? = nil,
    lastReminder: CompanionLifestyleReminderOccurrence? = nil,
    lastReminderByKind: [CompanionLifestyleReminderKind: Date] = [:],
    lastMeaningfulActivity: Date? = nil,
    quietHours: CompanionLifestyleQuietHours? = nil,
    activityState: CompanionLifestyleActivityState = .available,
    dailyCount: Int = 0
) -> CompanionLifestyleSchedulerContext {
    CompanionLifestyleSchedulerContext(
        now: now,
        appSessionStart: sessionStart,
        lastUserInteraction: lastUserInteraction,
        lastReminder: lastReminder,
        lastReminderByKind: lastReminderByKind,
        lastMeaningfulActivity: lastMeaningfulActivity,
        quietHours: quietHours,
        enabledKinds: [kind],
        activityState: activityState,
        dailyCounts: [kind: dailyCount]
    )
}

@main
private struct LifestyleSchedulerSmoke {
    static func main() {
        let scheduler = CompanionLifestyleScheduler(calendar: utcCalendar)

        let dueContexts: [(CompanionLifestyleReminderKind, CompanionLifestyleSchedulerContext)] = [
            (
                .morningGreeting,
                context(now: date(9, 30), sessionStart: date(6, 0), kind: .morningGreeting)
            ),
            (
                .hydration,
                context(now: date(10, 0), sessionStart: date(7, 0), kind: .hydration)
            ),
            (
                .sedentaryMovement,
                context(now: date(10, 0), sessionStart: date(7, 0), kind: .sedentaryMovement)
            ),
            (
                .eyeRest,
                context(now: date(10, 0), sessionStart: date(7, 0), kind: .eyeRest)
            ),
            (
                .focusEncouragement,
                context(
                    now: date(10, 0),
                    sessionStart: date(7, 0),
                    kind: .focusEncouragement,
                    activityState: .focusedWork(startedAt: date(8, 0))
                )
            ),
            (
                .hourlyTimeAnnouncement,
                context(
                    now: date(10, 1),
                    sessionStart: date(7, 0),
                    kind: .hourlyTimeAnnouncement
                )
            ),
            (
                .halfHourlyTimeAnnouncement,
                context(
                    now: date(10, 31),
                    sessionStart: date(7, 0),
                    kind: .halfHourlyTimeAnnouncement
                )
            ),
            (
                .lunch,
                context(now: date(12, 30), sessionStart: date(7, 0), kind: .lunch)
            ),
            (
                .eveningWindDown,
                context(now: date(19, 0), sessionStart: date(7, 0), kind: .eveningWindDown)
            ),
            (
                .lateNightRest,
                context(now: date(23, 15), sessionStart: date(7, 0), kind: .lateNightRest)
            )
        ]

        for (kind, testContext) in dueContexts {
            require(
                scheduler.decide(context: testContext, randomSeed: 7) == .play(kind: kind),
                "expected \(kind.rawValue) to play in its due window"
            )
        }

        let quietContext = context(
            now: date(23, 0),
            sessionStart: date(7, 0),
            kind: .lateNightRest,
            quietHours: CompanionLifestyleQuietHours(
                startHour: 22,
                startMinute: 0,
                endHour: 7,
                endMinute: 30
            )
        )
        require(
            scheduler.decide(context: quietContext, randomSeed: 1)
                == .silence(reason: .quietHours),
            "quiet hours did not suppress reminders"
        )

        let mediaContext = context(
            now: date(10, 0),
            sessionStart: date(7, 0),
            kind: .hydration,
            activityState: .mediaPlayback
        )
        let gameContext = context(
            now: date(10, 0),
            sessionStart: date(7, 0),
            kind: .hydration,
            activityState: .gameplay
        )
        require(
            scheduler.decide(context: mediaContext, randomSeed: 1)
                == .silence(reason: .mediaPlayback),
            "media playback was not suppressive"
        )
        require(
            scheduler.decide(context: gameContext, randomSeed: 1)
                == .silence(reason: .gameplay),
            "gameplay was not suppressive"
        )

        let focusedHealthContext = context(
            now: date(8, 30),
            sessionStart: date(6, 0),
            kind: .hydration,
            lastMeaningfulActivity: date(7, 0),
            activityState: .focusedWork(startedAt: date(8, 0))
        )
        guard case let .defer(focusedKind, focusedUntil, focusedReason) = scheduler.decide(
            context: focusedHealthContext,
            randomSeed: 5
        ) else {
            fputs("FAIL  focused work did not defer a newly due health reminder\n", stderr)
            exit(1)
        }
        require(focusedKind == .hydration, "focused deferral changed reminder kind")
        require(focusedReason == .focusedWork, "focused deferral used wrong reason")
        require(
            focusedUntil > date(8, 30) && focusedUntil <= date(8, 37),
            "focused deferral was not anchored to the original due time"
        )

        let overdueFocusedHealthContext = context(
            now: date(8, 45),
            sessionStart: date(6, 0),
            kind: .hydration,
            lastMeaningfulActivity: date(7, 0),
            activityState: .focusedWork(startedAt: date(8, 0))
        )
        require(
            scheduler.decide(context: overdueFocusedHealthContext, randomSeed: 5)
                == .play(kind: .hydration),
            "focused health reminder starved after its one-time deferral"
        )

        let recentReminder = CompanionLifestyleReminderOccurrence(
            kind: .morningGreeting,
            date: date(9, 50)
        )
        let intervalContext = context(
            now: date(10, 0),
            sessionStart: date(7, 0),
            kind: .hydration,
            lastReminder: recentReminder
        )
        require(
            scheduler.decide(context: intervalContext, randomSeed: 2)
                == .defer(
                    kind: .hydration,
                    until: date(10, 10),
                    reason: .minimumReminderInterval
                ),
            "global minimum interval was not enforced"
        )

        let sameKindContext = context(
            now: date(10, 20),
            sessionStart: date(7, 0),
            kind: .hydration,
            lastReminder: CompanionLifestyleReminderOccurrence(
                kind: .eyeRest,
                date: date(9, 50)
            ),
            lastReminderByKind: [.hydration: date(9, 30)]
        )
        var shortIntervalPolicy = CompanionLifestyleSchedulerPolicy()
        shortIntervalPolicy.intervalScale = 0.5
        let shortIntervalScheduler = CompanionLifestyleScheduler(
            policy: shortIntervalPolicy,
            calendar: utcCalendar
        )
        require(
            shortIntervalScheduler.decide(context: sameKindContext, randomSeed: 2)
                == .defer(
                    kind: .hydration,
                    until: date(10, 30),
                    reason: .sameKindCooldown
                ),
            "same-kind cooldown was not enforced"
        )

        let interactedContext = context(
            now: date(10, 0),
            sessionStart: date(7, 0),
            kind: .hydration,
            lastUserInteraction: date(9, 59)
        )
        require(
            scheduler.decide(context: interactedContext, randomSeed: 2)
                == .defer(
                    kind: .hydration,
                    until: date(10, 2),
                    reason: .recentUserInteraction
                ),
            "recent user interaction grace was not enforced"
        )

        let warmupContext = context(
            now: date(10, 0),
            sessionStart: date(9, 58),
            kind: .morningGreeting
        )
        require(
            scheduler.decide(context: warmupContext, randomSeed: 2)
                == .defer(
                    kind: .morningGreeting,
                    until: date(10, 3),
                    reason: .sessionWarmup
                ),
            "session warmup was not enforced"
        )

        let cappedContext = context(
            now: date(10, 0),
            sessionStart: date(7, 0),
            kind: .hydration,
            dailyCount: 6
        )
        require(
            scheduler.decide(context: cappedContext, randomSeed: 2)
                == .silence(reason: .dailyLimitsReached),
            "daily limit was not enforced"
        )

        let noEnabledContext = CompanionLifestyleSchedulerContext(
            now: date(10, 0),
            appSessionStart: date(7, 0),
            enabledKinds: []
        )
        require(
            scheduler.decide(context: noEnabledContext, randomSeed: 2)
                == .silence(reason: .noEnabledReminders),
            "disabled reminder state was not silent"
        )

        let idleFocusContext = CompanionLifestyleSchedulerContext(
            now: date(10, 0),
            appSessionStart: date(7, 0),
            enabledKinds: [.focusEncouragement],
            activityState: .available
        )
        require(
            scheduler.decide(context: idleFocusContext, randomSeed: 2)
                == .silence(reason: .noEligibleReminder),
            "idle-only focus encouragement reported a false daily limit"
        )

        let outsideClockWindow = context(
            now: date(10, 5),
            sessionStart: date(7, 0),
            kind: .hourlyTimeAnnouncement
        )
        guard case let .defer(kind, until, reason) = scheduler.decide(
            context: outsideClockWindow,
            randomSeed: 9
        ) else {
            fputs("FAIL  missed time-announcement window was not deferred\n", stderr)
            exit(1)
        }
        require(kind == .hourlyTimeAnnouncement, "wrong deferred clock kind")
        require(reason == .scheduledTime, "wrong deferred clock reason")
        require(until >= date(11, 0) && until <= date(11, 0, 45), "clock window was too wide")

        let blockedClockContext = context(
            now: date(10, 1),
            sessionStart: date(7, 0),
            kind: .hourlyTimeAnnouncement,
            lastReminder: CompanionLifestyleReminderOccurrence(
                kind: .hydration,
                date: date(9, 55)
            )
        )
        require(
            scheduler.decide(context: blockedClockContext, randomSeed: 7)
                == .silence(reason: .narrowTimeWindowBlocked),
            "a blocked time announcement escaped its narrow window"
        )

        let deterministicContext = context(
            now: date(8, 0),
            sessionStart: date(7, 0),
            kind: .hydration
        )
        let deterministicA = scheduler.decide(context: deterministicContext, randomSeed: 0xC0FFEE)
        let deterministicB = scheduler.decide(context: deterministicContext, randomSeed: 0xC0FFEE)
        require(deterministicA == deterministicB, "seeded jitter was not deterministic")

        let penaltyFreeA = scheduler.decide(context: dueContexts[1].1, randomSeed: 11)
        let penaltyFreeB = scheduler.decide(context: dueContexts[1].1, randomSeed: 11)
        require(
            penaltyFreeA == .play(kind: .hydration) && penaltyFreeB == penaltyFreeA,
            "a missed or failed presentation could mutate scheduler behavior"
        )

        print("PASS  all lifestyle reminder kinds")
        print("PASS  quiet/media/game suppression")
        print("PASS  low-interruption deferrals and limits")
        print("PASS  narrow hourly and half-hour windows")
        print("PASS  focused-work health downgrade")
        print("PASS  injected time and deterministic jitter")
        print("PASS  stateless failure-without-penalty behavior")
    }
}
