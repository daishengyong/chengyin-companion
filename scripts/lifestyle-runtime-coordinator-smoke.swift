import Foundation

protocol CompanionErrorCoding: Error {
    var companionErrorCode: String { get }
}

enum SmokeFailure: Error {
    case failed(String)
}

func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else { throw SmokeFailure.failed(message) }
}

@main
struct LifestyleRuntimeCoordinatorSmoke {
    @MainActor
    static func main() throws {
        let suiteName = "chengyin.lifestyle-runtime-smoke.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SmokeFailure.failed("could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(
            from: DateComponents(
                year: 2026,
                month: 8,
                day: 9,
                hour: 12,
                minute: 0
            )
        )!
        let store = CompanionLifestyleMemoryStore(
            userDefaults: defaults,
            storageKey: "runtime-primary",
            backupKey: "runtime-backup"
        )
        let adapter = CompanionLifestyleMemoryAdapter(
            store: store,
            now: start,
            calendar: calendar
        )
        let runtime = CompanionLifestyleRuntimeCoordinator(
            memoryAdapter: adapter,
            now: start
        )

        let disabled = runtime.evaluate(
            at: start,
            remindersEnabled: false,
            userRecentlyActive: true,
            quietHoursEnabled: false,
            timeAnnouncementsEnabled: true,
            halfHourlyAnnouncementsEnabled: true,
            cadence: .standard,
            activityState: .available,
            calendar: calendar
        )
        try expect(disabled.outcome == .disabled, "disabled state drifted")

        let pauseEnd = start.addingTimeInterval(60 * 60)
        try expect(
            runtime.pause(until: pauseEnd, at: start) == nil,
            "pause persistence failed"
        )
        let paused = runtime.evaluate(
            at: start.addingTimeInterval(60),
            remindersEnabled: true,
            userRecentlyActive: true,
            quietHoursEnabled: false,
            timeAnnouncementsEnabled: false,
            halfHourlyAnnouncementsEnabled: false,
            cadence: .gentle,
            activityState: .focusedWork(startedAt: start),
            calendar: calendar
        )
        try expect(
            paused.outcome == .paused(until: pauseEnd),
            "pause deadline was not preserved"
        )
        try expect(runtime.resume(at: start) == nil, "resume persistence failed")

        let awayAt = start.addingTimeInterval(10 * 60)
        let away = runtime.evaluate(
            at: awayAt,
            remindersEnabled: true,
            userRecentlyActive: false,
            quietHoursEnabled: false,
            timeAnnouncementsEnabled: false,
            halfHourlyAnnouncementsEnabled: false,
            cadence: .standard,
            activityState: .available,
            calendar: calendar
        )
        try expect(away.outcome == .away, "away state drifted")

        let returnedAt = awayAt.addingTimeInterval(60)
        let settling = runtime.evaluate(
            at: returnedAt,
            remindersEnabled: true,
            userRecentlyActive: true,
            quietHoursEnabled: false,
            timeAnnouncementsEnabled: false,
            halfHourlyAnnouncementsEnabled: false,
            cadence: .standard,
            activityState: .available,
            calendar: calendar
        )
        try expect(
            settling.outcome == .returnedSettling,
            "return settling state drifted"
        )
        let resumeAt = returnedAt.addingTimeInterval(5 * 60)
        let cooling = runtime.evaluate(
            at: returnedAt.addingTimeInterval(2 * 60),
            remindersEnabled: true,
            userRecentlyActive: true,
            quietHoursEnabled: false,
            timeAnnouncementsEnabled: false,
            halfHourlyAnnouncementsEnabled: false,
            cadence: .lively,
            activityState: .available,
            calendar: calendar
        )
        try expect(
            cooling.outcome == .returnedCoolingDown(until: resumeAt),
            "return cooldown deadline drifted"
        )
        let resumed = runtime.evaluate(
            at: resumeAt.addingTimeInterval(1),
            remindersEnabled: true,
            userRecentlyActive: true,
            quietHoursEnabled: false,
            timeAnnouncementsEnabled: false,
            halfHourlyAnnouncementsEnabled: false,
            cadence: .lively,
            activityState: .available,
            calendar: calendar
        )
        if case .returnedCoolingDown = resumed.outcome {
            throw SmokeFailure.failed("return cooldown did not clear")
        }

        let deliveryAt = resumeAt.addingTimeInterval(30)
        try expect(
            runtime.recordDelivered(.hydration, at: deliveryAt) == nil,
            "delivery persistence failed"
        )
        try expect(
            adapter.state.lastReminder
                == CompanionLifestyleReminderOccurrence(
                    kind: .hydration,
                    date: deliveryAt
                ),
            "delivered reminder was not recorded"
        )

        let quietAt = calendar.date(
            from: DateComponents(
                year: 2026,
                month: 8,
                day: 10,
                hour: 1,
                minute: 0
            )
        )!
        let quietRuntime = CompanionLifestyleRuntimeCoordinator(
            memoryAdapter: adapter,
            now: quietAt.addingTimeInterval(-20 * 60)
        )
        let quiet = quietRuntime.evaluate(
            at: quietAt,
            remindersEnabled: true,
            userRecentlyActive: true,
            quietHoursEnabled: true,
            timeAnnouncementsEnabled: true,
            halfHourlyAnnouncementsEnabled: true,
            cadence: .standard,
            activityState: .available,
            calendar: calendar
        )
        try expect(
            quiet.outcome == .silence(reason: .quietHours),
            "quiet-hours boundary drifted"
        )

        try expect(runtime.reset(at: quietAt) == nil, "reset persistence failed")
        try expect(adapter.state.lastReminder == nil, "reset retained reminder")
        try expect(adapter.state.dailyCounts.isEmpty, "reset retained counts")
        try expect(runtime.pausedUntil == nil, "reset retained pause")

        print(
            "Lifestyle runtime coordinator smoke: PASS "
                + "(disabled, pause/resume, away/return, quiet hours, delivery, reset)"
        )
    }
}
