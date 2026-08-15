import CompanionContracts
import Foundation

private struct SmokeFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw SmokeFailure(description: message)
    }
}

@main
private struct CodexEventWatcherSmoke {
    static func main() async throws {
        try extractorChecks()
        try voiceLineSafetyChecks()
        try await watcherChecks()
        print("codex event watcher smoke passed")
    }

    private static func extractorChecks() throws {
        let now = Date()
        let startedAt = now.addingTimeInterval(-1)
        let types = CompanionEventType.allCases

        for (index, type) in types.enumerated() {
            let event = CompanionEvent(
                eventId: eventID(index),
                source: "codex-skill",
                sourceVersion: "terminal-events-v1",
                type: type,
                taskRef: "opaque-task-\(index)",
                occurredAt: now,
                durationMs: 12_345,
                outcome: outcome(for: type)
            )
            let data = try CompanionEventCodec.encode(event, now: now)
            let signal = CodexProtocolEventExtractor.signal(
                from: data,
                startedAt: startedAt,
                now: now
            )
            try require(signal != nil, "\(type.rawValue) was not extracted")
            try require(signal?.type == type, "\(type.rawValue) changed unexpectedly")
            try require(signal?.duration == 12.345, "\(type.rawValue) lost duration")
            if type == .integrationHealth || type == .integrationDisconnected {
                try require(signal?.taskRef == nil, "Integration event retained a task reference")
            } else {
                try require(
                    signal?.taskRef == "opaque-task-\(index)",
                    "\(type.rawValue) lost its opaque task reference"
                )
            }
        }

        let unsafeReference = CompanionEvent(
            source: "codex",
            type: .taskProgress,
            taskRef: "/Users/example/private-project",
            occurredAt: now
        )
        let unsafeData = try CompanionEventCodec.encode(unsafeReference, now: now)
        let sanitized = CodexProtocolEventExtractor.signal(
            from: unsafeData,
            startedAt: startedAt,
            now: now
        )
        try require(sanitized?.taskRef == nil, "A path-like task reference was retained")

        let privateEvent = CompanionEvent(
            source: "codex",
            type: .taskStarted,
            occurredAt: now,
            privacy: CompanionEventPrivacy(containsPrompt: true)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let privateData = try encoder.encode(privateEvent)
        try require(
            CodexProtocolEventExtractor.signal(
                from: privateData,
                startedAt: startedAt,
                now: now
            ) == nil,
            "An event declaring private payload was accepted"
        )

        let staleEvent = CompanionEvent(
            source: "codex",
            type: .taskStarted,
            occurredAt: startedAt.addingTimeInterval(-4)
        )
        let staleData = try CompanionEventCodec.encode(staleEvent, now: now)
        try require(
            CodexProtocolEventExtractor.signal(
                from: staleData,
                startedAt: startedAt,
                now: now
            ) == nil,
            "A stale event was replayed"
        )

        let excessiveDuration = CompanionEvent(
            source: "codex",
            type: .taskLongRunning,
            occurredAt: now,
            durationMs: CodexProtocolEventExtractor.maximumRetainedDurationMs + 1
        )
        let excessiveData = try CompanionEventCodec.encode(excessiveDuration, now: now)
        let bounded = CodexProtocolEventExtractor.signal(
            from: excessiveData,
            startedAt: startedAt,
            now: now
        )
        try require(bounded?.duration == 0, "An excessive duration reached the scheduler")

        let failedCompletion = CompanionEvent(
            source: "codex-skill",
            sourceVersion: "terminal-events-v1",
            type: .taskCompleted,
            occurredAt: now,
            outcome: .failure
        )
        try require(
            CodexProtocolEventExtractor.signal(
                from: failedCompletion,
                startedAt: startedAt
            )?.type == .taskFailed,
            "A failed completion would be celebrated"
        )

        for outcome in [CompanionEventOutcome?.none, .some(.unknown)] {
            let ambiguous = CompanionEvent(
                source: "codex-skill",
                sourceVersion: "terminal-events-v1",
                type: .taskCompleted,
                occurredAt: now,
                outcome: outcome
            )
            let signal = CodexProtocolEventExtractor.signal(
                from: ambiguous,
                startedAt: startedAt
            )
            try require(
                signal?.type == .responseReady,
                "An ambiguous completion would be celebrated"
            )
            try require(
                signal?.isTrustedTaskCompletion == false,
                "An ambiguous completion was marked trusted"
            )
        }

        let forgedCompletion = CompanionEvent(
            source: "local-helper",
            sourceVersion: "terminal-events-v1",
            type: .taskCompleted,
            occurredAt: now,
            outcome: .success
        )
        let forgedSignal = CodexProtocolEventExtractor.signal(
            from: forgedCompletion,
            startedAt: startedAt
        )
        try require(
            forgedSignal?.type == .responseReady
                && forgedSignal?.origin == .explicitProtocol
                && forgedSignal?.isTrustedTaskCompletion == false,
            "An unregistered producer could claim task completion"
        )

        let appServerFailure = CompanionEvent(
            source: "codex-app-server",
            sourceVersion: "turn-events-v1",
            type: .taskFailed,
            occurredAt: now,
            outcome: .failure
        )
        try require(
            CodexProtocolEventExtractor.signal(
                from: appServerFailure,
                startedAt: startedAt
            )?.type == .taskFailed,
            "A registered App Server failure lost its terminal meaning"
        )
    }

    private static func voiceLineSafetyChecks() throws {
        let library = VoiceLineLibrary(
            lines: [
                VoiceLine(
                    id: "unsafe",
                    event: .taskComplete,
                    action: .cheer,
                    text: "task completion claim",
                    audioFile: "unsafe.mp3",
                    addressed: false
                ),
                VoiceLine(
                    id: "safe",
                    event: .focusEncouragement,
                    action: .cheer,
                    text: "neutral encouragement",
                    audioFile: "safe.mp3",
                    addressed: false
                )
            ]
        )
        let candidates = library.candidates(
            for: .cheer,
            addressedEnabled: true,
            excluding: []
        )
        try require(
            candidates.map(\.id) == ["safe"],
            "Manual action audio could still make a task lifecycle claim"
        )
    }

    private static func watcherChecks() async throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("chengyin-event-smoke-\(UUID().uuidString)", isDirectory: true)
        let sessionRoot = temporaryRoot.appendingPathComponent("sessions", isDirectory: true)
        let protocolRoot = temporaryRoot.appendingPathComponent("events", isDirectory: true)
        try FileManager.default.createDirectory(
            at: sessionRoot,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        let startedAt = Date()
        let watcher = CodexCompletionWatcher(
            root: sessionRoot,
            protocolRoot: protocolRoot,
            startedAt: startedAt,
            legacySessionsEnabled: true
        )
        await watcher.prime()

        for (index, type) in CompanionEventType.allCases.enumerated() {
            let event = CompanionEvent(
                eventId: eventID(index),
                source: "codex-skill",
                sourceVersion: "terminal-events-v1",
                type: type,
                taskRef: "task-\(index)",
                occurredAt: startedAt,
                durationMs: Int64(index * 1_000),
                outcome: outcome(for: type)
            )
            let data = try CompanionEventCodec.encode(event)
            try writeProtocolEvent(data, to: protocolRoot, named: "\(event.eventId).json")
            if index == 0 {
                try writeProtocolEvent(
                    data,
                    to: protocolRoot,
                    named: "\(eventID(100)).json"
                )
            }
        }

        let legacyURL = sessionRoot.appendingPathComponent("session.jsonl")
        let timestamp = startedAt.timeIntervalSince1970
        let legacyRows = """
        {"type":"event_msg","payload":{"type":"task_started","turn_id":"legacy-start"}}
        {"type":"event_msg","payload":{"type":"task_progress","turn_id":"legacy-progress"}}
        {"type":"event_msg","payload":{"type":"task_complete","turn_id":"legacy-complete","completed_at":\(timestamp),"duration_ms":5000}}

        """
        try Data(legacyRows.utf8).write(to: legacyURL)

        let signals = await watcher.poll()
        try require(
            signals.count == CompanionEventType.allCases.count + 1,
            "Expected every protocol type plus one neutral legacy boundary, received \(signals.count)"
        )
        for type in CompanionEventType.allCases {
            try require(
                signals.contains(where: { $0.type == type }),
                "Watcher did not emit \(type.rawValue)"
            )
        }
        try require(
            signals.filter { $0.id.hasPrefix("legacy-") }.map(\.id) == ["legacy-complete"],
            "Legacy JSONL emitted an unexpected event"
        )
        try require(
            signals.first(where: { $0.id == "legacy-complete" })?.type == .responseReady,
            "Legacy turn boundary was incorrectly treated as task completion"
        )
        try require(
            signals.first(where: { $0.id == "legacy-complete" })?.isTrustedTaskCompletion == false,
            "Legacy turn boundary was incorrectly trusted"
        )
        let repeatedSignals = await watcher.poll()
        try require(repeatedSignals.isEmpty, "Unchanged files were delivered twice")

        let restartedAt = Date()
        let restartedWatcher = CodexCompletionWatcher(
            root: sessionRoot,
            protocolRoot: protocolRoot,
            startedAt: restartedAt
        )
        await restartedWatcher.prime()
        let restartBaselineSignals = await restartedWatcher.poll()
        try require(
            restartBaselineSignals.isEmpty,
            "A restart replayed a pre-existing event"
        )
        let freshAfterRestart = CompanionEvent(
            source: "codex-skill",
            sourceVersion: "terminal-events-v1",
            type: .taskCompleted,
            occurredAt: Date(),
            outcome: .success
        )
        try writeProtocolEvent(
            try CompanionEventCodec.encode(freshAfterRestart),
            to: protocolRoot,
            named: "\(freshAfterRestart.eventId).json"
        )
        let freshSignals = await restartedWatcher.poll()
        try require(
            freshSignals.count == 1
                && freshSignals[0].id == freshAfterRestart.eventId
                && freshSignals[0].isTrustedTaskCompletion,
            "A fresh post-restart terminal event was not delivered exactly once"
        )

        try FileManager.default.removeItem(at: protocolRoot)
        try FileManager.default.createSymbolicLink(
            at: protocolRoot,
            withDestinationURL: sessionRoot
        )
        let disconnected = await watcher.pollWithHealth()
        try require(
            disconnected.signals.isEmpty
                && disconnected.eventBridgeHealth.isReady == false
                && disconnected.eventBridgeHealth.code == "EVENT_SPOOL_ROOT_UNSAFE",
            "A symbolic event root did not produce a privacy-safe disconnect"
        )
        try FileManager.default.removeItem(at: protocolRoot)
        let repair = await watcher.repairProtocolBridge()
        try require(repair.isReady, "Missing event root did not repair safely")
        let restored = await watcher.pollWithHealth()
        try require(
            restored.eventBridgeHealth == CodexEventBridgeHealth(isReady: true, code: nil),
            "A repaired event root did not return to healthy"
        )

        let disabledSessionRoot = temporaryRoot.appendingPathComponent(
            "disabled-sessions",
            isDirectory: true
        )
        let disabledProtocolRoot = temporaryRoot.appendingPathComponent(
            "disabled-events",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: disabledSessionRoot,
            withIntermediateDirectories: true
        )
        let disabledWatcher = CodexCompletionWatcher(
            root: disabledSessionRoot,
            protocolRoot: disabledProtocolRoot,
            startedAt: startedAt
        )
        await disabledWatcher.prime()
        try Data(legacyRows.utf8).write(
            to: disabledSessionRoot.appendingPathComponent("session.jsonl")
        )
        let disabledSignals = await disabledWatcher.poll()
        try require(
            disabledSignals.isEmpty,
            "Legacy session adapter was not disabled by default"
        )
    }

    private static func outcome(for type: CompanionEventType) -> CompanionEventOutcome? {
        switch type {
        case .taskCompleted:
            .success
        case .taskFailed:
            .failure
        case .taskCancelled:
            .cancelled
        default:
            nil
        }
    }

    private static func eventID(_ index: Int) -> String {
        String(format: "00000000-0000-4000-8000-%012d", index + 1)
    }

    private static func writeProtocolEvent(
        _ data: Data,
        to root: URL,
        named name: String
    ) throws {
        let destination = root.appendingPathComponent(name)
        try data.write(to: destination, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: destination.path
        )
    }
}
