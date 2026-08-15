import CompanionContracts
import Foundation

private struct SmokeFailure: Error, CustomStringConvertible {
    let description: String
}

@MainActor
private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else {
        throw SmokeFailure(description: message)
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
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return condition()
}

@main
@MainActor
private struct CompanionWorkdayRuntimeCoordinatorSmoke {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "chengyin-workday-runtime-\(UUID().uuidString)",
            isDirectory: true
        )
        let eventRoot = root.appendingPathComponent("events", isDirectory: true)
        let sessionRoot = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(
            at: sessionRoot,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let suite = "chengyin.workday-runtime.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw SmokeFailure(description: "Could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let startedAt = Date()
        let store = CompanionWorkdayStateStore(
            userDefaults: defaults,
            storageKey: "workday",
            backupKey: "workday.backup"
        )
        let adapter = CompanionWorkdayAdapter(store: store, now: startedAt)
        let watcher = CodexCompletionWatcher(
            root: sessionRoot,
            protocolRoot: eventRoot,
            startedAt: startedAt
        )
        let runtime = CompanionWorkdayRuntimeCoordinator(
            adapter: adapter,
            watcher: watcher
        )

        var announcementsEnabled = true
        var readinessChanges = 0
        var observed: [CompanionWorkdayRuntimeReceipt] = []
        runtime.startPolling(
            every: 15_000_000,
            announcementsEnabled: { announcementsEnabled },
            onSignal: { signal in
                observed.append(
                    runtime.consume(
                        signal,
                        allowsPassivePresenceUpdate: true
                    )
                )
            },
            onReadinessChanged: { readinessChanges += 1 }
        )
        let bridgeBecameReady = await waitUntil(timeout: 1) {
            runtime.eventBridgeReady
        }
        try require(
            bridgeBecameReady,
            "Event bridge did not become ready"
        )
        try require(readinessChanges == 1, "Readiness callback was not exact-once")

        try writeEvent(
            type: .taskStarted,
            outcome: nil,
            taskRef: "opaque-shared-task",
            at: startedAt,
            root: eventRoot
        )
        try writeEvent(
            type: .taskCompleted,
            outcome: .unknown,
            taskRef: "opaque-shared-task",
            at: startedAt.addingTimeInterval(1),
            root: eventRoot
        )
        try writeEvent(
            type: .taskCompleted,
            outcome: .success,
            taskRef: "opaque-shared-task",
            at: startedAt.addingTimeInterval(2),
            root: eventRoot
        )
        let receivedInitialArc = await waitUntil(timeout: 2) {
            observed.count == 3
        }
        try require(
            receivedInitialArc,
            "Expected start, neutral boundary and trusted completion"
        )
        try require(
            runtime.state.startedCount == 1
                && runtime.state.responseReadyCount == 1
                && runtime.state.completedCount == 1,
            "False or duplicate completion reached workday state"
        )
        try require(!runtime.hasActiveWork, "Trusted terminal did not end active work")
        try require(
            observed.contains { receipt in
                if case .responseReady = receipt.decision { return true }
                return false
            },
            "Ambiguous completion was not projected as response-ready"
        )
        try require(
            observed.contains { receipt in
                if case .taskComplete = receipt.presentation.event { return true }
                return false
            },
            "Trusted completion lost its semantic presentation"
        )

        guard let responseReceipt = observed.first(where: { receipt in
            if case .responseReady = receipt.decision { return true }
            return false
        }) else {
            throw SmokeFailure(description: "Response-ready receipt was unavailable")
        }
        let responseApplication = CompanionWorkdayApplicationProjection.project(
            responseReceipt.presentation
        )
        try require(
            responseApplication.event == .responseReady
                && responseApplication.relationship == nil
                && responseApplication.visual != .completed,
            "Response-ready was reinterpreted as a completion side effect"
        )

        guard let completionReceipt = observed.first(where: { receipt in
            if case .completed = receipt.decision { return true }
            return false
        }) else {
            throw SmokeFailure(description: "Trusted completion receipt was unavailable")
        }
        let completionApplication = CompanionWorkdayApplicationProjection.project(
            completionReceipt.presentation
        )
        try require(
            completionApplication.visual == .completed
                && completionApplication.relationship?.momentID == "task.completed",
            "Trusted completion did not retain its completion-only effects"
        )

        let malformedResponse = CompanionWorkdayPresentationPlan(
            visual: .completed,
            event: .responseReady,
            relationshipReward: CompanionWorkdayRelationshipReward(
                bond: 99,
                chemistry: 99,
                milestones: [.firstCompletion, .longFocus]
            )
        )
        let sanitizedResponse = CompanionWorkdayApplicationProjection.project(
            malformedResponse
        )
        try require(
            sanitizedResponse.event == .responseReady
                && sanitizedResponse.visual == nil
                && sanitizedResponse.relationship == nil,
            "Malformed non-terminal input escaped the completion-only projection gate"
        )

        runtime.stopPolling()
        let countBeforeStop = observed.count
        try writeEvent(
            type: .taskFailed,
            outcome: .failure,
            taskRef: "opaque-stopped-task",
            at: Date(),
            root: eventRoot
        )
        try? await Task.sleep(nanoseconds: 80_000_000)
        try require(observed.count == countBeforeStop, "Stopped poller delivered a signal")

        runtime.startPolling(
            every: 15_000_000,
            announcementsEnabled: { announcementsEnabled },
            onSignal: { signal in
                observed.append(
                    runtime.consume(
                        signal,
                        allowsPassivePresenceUpdate: true
                    )
                )
            },
            onReadinessChanged: { readinessChanges += 1 }
        )
        let resumedPendingEvent = await waitUntil(timeout: 2) {
            observed.count == countBeforeStop + 1
        }
        try require(
            resumedPendingEvent,
            "Restarted poller did not resume pending local events"
        )
        try require(runtime.state.failedCount == 1, "Failure did not reach state once")

        announcementsEnabled = false
        try writeEvent(
            type: .taskCompleted,
            outcome: .success,
            taskRef: "opaque-disabled-task",
            at: Date(),
            root: eventRoot
        )
        try? await Task.sleep(nanoseconds: 100_000_000)
        announcementsEnabled = true
        try? await Task.sleep(nanoseconds: 80_000_000)
        try require(
            runtime.state.completedCount == 1,
            "A disabled announcement was replayed later as completion"
        )

        let healthSignalStart = observed.count
        let readinessBeforeHealth = readinessChanges
        try FileManager.default.removeItem(at: eventRoot)
        try FileManager.default.createSymbolicLink(
            at: eventRoot,
            withDestinationURL: sessionRoot
        )
        let disconnected = await waitUntil(timeout: 2) {
            !runtime.eventBridgeReady && observed.count == healthSignalStart + 1
        }
        try require(disconnected, "Live unsafe-root transition was not observed")
        try require(
            runtime.eventBridgeCode == "EVENT_SPOOL_ROOT_UNSAFE",
            "Live disconnect lost its stable recovery code"
        )
        try require(
            observed.contains { receipt in
                if case .integrationDisconnected = receipt.decision { return true }
                return false
            },
            "Live disconnect did not reach the shared workday policy"
        )

        try FileManager.default.removeItem(at: eventRoot)
        try FileManager.default.createDirectory(
            at: eventRoot,
            withIntermediateDirectories: false
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: eventRoot.path
        )
        let reconnected = await waitUntil(timeout: 2) {
            runtime.eventBridgeReady && observed.count == healthSignalStart + 2
        }
        try require(reconnected, "Live event bridge recovery was not observed")
        try require(runtime.eventBridgeCode == nil, "Recovered bridge retained an error code")
        try require(
            observed.contains { receipt in
                if case .integrationHealthy = receipt.decision { return true }
                return false
            },
            "Live recovery did not reach the shared workday policy"
        )
        try require(
            readinessChanges == readinessBeforeHealth + 2,
            "Readiness transitions were not exact-once"
        )

        var expirations = 0
        _ = runtime.openCompletionReplyWindow(for: 0.06) { expirations += 1 }
        try? await Task.sleep(nanoseconds: 20_000_000)
        _ = runtime.openCompletionReplyWindow(for: 0.14) { expirations += 1 }
        try? await Task.sleep(nanoseconds: 70_000_000)
        try require(
            runtime.completionReplyWindowActive && expirations == 0,
            "An older reply timer closed the newer reply window"
        )
        let replyExpired = await waitUntil(timeout: 1) {
            !runtime.completionReplyWindowActive
        }
        try require(
            replyExpired,
            "Reply window did not expire"
        )
        try require(expirations == 1, "Reply expiry was not exact-once")

        _ = runtime.openCompletionReplyWindow(for: 0.04) { expirations += 1 }
        runtime.closeCompletionReplyWindow()
        try? await Task.sleep(nanoseconds: 70_000_000)
        try require(expirations == 1, "Closed reply window emitted a stale callback")

        try runtime.resetDay(at: Date())
        try require(
            runtime.state.startedCount == 0
                && runtime.state.completedCount == 0
                && runtime.state.failedCount == 0,
            "Explicit workday reset did not clear the coordinated snapshot"
        )
        runtime.stopPolling()

        print(
            "PASS  workday runtime coordinator: trusted lifecycle, cancellable polling, "
                + "generation-safe reply window and privacy-minimal reset"
        )
    }

    private static func writeEvent(
        type: CompanionEventType,
        outcome: CompanionEventOutcome?,
        taskRef: String,
        at date: Date,
        root: URL
    ) throws {
        let event = CompanionEvent(
            source: "codex-skill",
            sourceVersion: "terminal-events-v1",
            type: type,
            taskRef: taskRef,
            occurredAt: date,
            outcome: outcome
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
