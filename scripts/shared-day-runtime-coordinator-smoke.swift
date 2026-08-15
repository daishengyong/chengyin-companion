import CompanionContracts
import Foundation

private struct SharedDaySmokeFailure: Error, CustomStringConvertible {
    let description: String
}

@MainActor
private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else {
        throw SharedDaySmokeFailure(description: message)
    }
}

@MainActor
private func waitUntil(
    timeout: TimeInterval,
    condition: () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return condition()
}

@main
@MainActor
private struct CompanionSharedDayRuntimeCoordinatorSmoke {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "chengyin-shared-day-runtime-\(UUID().uuidString)",
            isDirectory: true
        )
        let eventRoot = root.appendingPathComponent("events", isDirectory: true)
        let sessionRoot = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(
            at: sessionRoot,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let suite = "chengyin.shared-day-runtime.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw SharedDaySmokeFailure(description: "Could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let startedAt = Date()
        let workday = CompanionWorkdayRuntimeCoordinator(
            adapter: CompanionWorkdayAdapter(
                store: CompanionWorkdayStateStore(
                    userDefaults: defaults,
                    storageKey: "workday",
                    backupKey: "workday.backup"
                ),
                now: startedAt
            ),
            watcher: CodexCompletionWatcher(
                root: sessionRoot,
                protocolRoot: eventRoot,
                startedAt: startedAt
            )
        )
        let lifestyle = CompanionLifestyleRuntimeCoordinator(
            memoryAdapter: CompanionLifestyleMemoryAdapter(
                store: CompanionLifestyleMemoryStore(
                    userDefaults: defaults,
                    storageKey: "care",
                    backupKey: "care.backup"
                ),
                now: startedAt
            ),
            now: startedAt
        )
        let runtime = CompanionSharedDayRuntimeCoordinator(
            workday: workday,
            lifestyle: lifestyle
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let timePlan = CompanionLifestyleEventProjection.deliveryPlan(
            for: .halfHourlyTimeAnnouncement,
            at: calendar.date(
                from: DateComponents(
                    year: 2026,
                    month: 8,
                    day: 11,
                    hour: 14,
                    minute: 30
                )
            )!,
            allowsFlirtyEncouragement: false,
            calendar: calendar
        )
        try require(
            timePlan.event == .timeAnnouncement
                && timePlan.preferredVoiceLineID == "time_14_30",
            "Time care lost its matching voice-line projection"
        )
        try require(
            CompanionLifestyleEventProjection.deliveryPlan(
                for: .focusEncouragement,
                at: startedAt,
                allowsFlirtyEncouragement: true
            ).event == .flirt,
            "Opt-in flirty encouragement lost its semantic event"
        )
        let disabledFacts = CompanionSharedDayCareFacts(
            remindersEnabled: false,
            userRecentlyActive: true,
            quietHoursEnabled: false,
            timeAnnouncementsEnabled: false,
            halfHourlyAnnouncementsEnabled: false,
            cadence: .standard,
            activityState: .focusedWork(startedAt: startedAt)
        )

        let direct = runtime.evaluateCare(at: startedAt, facts: disabledFacts)
        try require(direct.lifestyle.outcome == .disabled, "Direct care receipt drifted")
        try require(
            direct.workdayPersistenceError == nil,
            "One shared tick did not refresh the workday cleanly"
        )

        var careReceipts = 0
        var workSignals: [CodexTaskSignal] = []
        var readinessChanges = 0
        runtime.start(
            careEvery: 15_000_000,
            workEvery: 15_000_000,
            careFacts: { disabledFacts },
            onCareReceipt: { receipt, _ in
                if receipt.lifestyle.outcome == .disabled {
                    careReceipts += 1
                }
            },
            announcementsEnabled: { true },
            onWorkSignal: { workSignals.append($0) },
            onReadinessChanged: { readinessChanges += 1 }
        )
        let careBegan = await waitUntil(timeout: 1) { careReceipts >= 2 }
        try require(careBegan, "Shared care clock did not begin")
        try require(readinessChanges == 1, "Shared workday readiness was not exact-once")

        let beforeRestart = careReceipts
        runtime.start(
            careEvery: 250_000_000,
            workEvery: 15_000_000,
            careFacts: { disabledFacts },
            onCareReceipt: { _, _ in careReceipts += 1 },
            announcementsEnabled: { true },
            onWorkSignal: { workSignals.append($0) },
            onReadinessChanged: { readinessChanges += 1 }
        )
        try? await Task.sleep(nanoseconds: 80_000_000)
        try require(
            careReceipts == beforeRestart,
            "A replaced care generation emitted a stale callback"
        )

        try writeEvent(
            type: .taskStarted,
            taskRef: "opaque-shared-day-task",
            at: Date(),
            root: eventRoot
        )
        let signalArrived = await waitUntil(timeout: 2) { workSignals.count == 1 }
        try require(signalArrived, "Shared workday clock did not deliver a trusted signal")

        runtime.stop()
        let stoppedCareCount = careReceipts
        let stoppedSignalCount = workSignals.count
        try writeEvent(
            type: .taskFailed,
            taskRef: "opaque-stopped-task",
            at: Date(),
            root: eventRoot
        )
        try? await Task.sleep(nanoseconds: 320_000_000)
        try require(
            careReceipts == stoppedCareCount,
            "Stopped shared day emitted a care callback"
        )
        try require(
            workSignals.count == stoppedSignalCount,
            "Stopped shared day emitted a work callback"
        )

        print(
            "PASS  shared-day runtime coordinator: one bounded care receipt, "
                + "time/encouragement projection, generation-safe restart, "
                + "trusted work signal and exact stop"
        )
    }

    private static func writeEvent(
        type: CompanionEventType,
        taskRef: String,
        at date: Date,
        root: URL
    ) throws {
        let event = CompanionEvent(
            source: "codex",
            type: type,
            taskRef: taskRef,
            occurredAt: date,
            outcome: type == .taskFailed ? .failure : nil
        )
        let data = try CompanionEventCodec.encode(event)
        let destination = root.appendingPathComponent("\(event.eventId).json")
        try data.write(to: destination, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: destination.path
        )
    }
}
