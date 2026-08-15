import CompanionContracts
import Darwin
import Foundation

private enum EmitterError: Error, LocalizedError {
    case usage
    case invalidEventType
    case invalidDuration
    case invalidEventRoot

    var errorDescription: String? {
        switch self {
        case .usage:
            """
            Usage:
              CompanionEventEmitter <response.ready|task.started|task.progress|task.completed|task.failed|task.cancelled|task.long_running> [duration_ms]
              CompanionEventEmitter codex-notify '<codex_notify_json>'
              CompanionEventEmitter codex-app-server '<server_notification_json>'
              CompanionEventEmitter codex-config-plan <absolute-helper-path> [config-path]

            Set CHENGYIN_EVENT_ROOT to an absolute temporary directory when
            emitting test events so validation never reaches the live app.
            """
        case .invalidEventType:
            "Unsupported task event type."
        case .invalidDuration:
            "duration_ms must be a non-negative integer."
        case .invalidEventRoot:
            "CHENGYIN_EVENT_ROOT must be an absolute path without control characters."
        }
    }
}

@main
private struct CompanionEventEmitter {
    static func main() {
        do {
            try emit(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            if let mapperError = error as? CodexAppServerMapperError {
                fputs(
                    "FAIL [\(mapperError.companionErrorCode)] \(mapperError.localizedDescription)\n"
                        + "ACTION \(mapperError.recoveryAction)\n",
                    stderr
                )
            } else {
                fputs("\(error.localizedDescription)\n", stderr)
            }
            exit(2)
        }
    }

    private static func emit(arguments: [String]) throws {
        if (2...3).contains(arguments.count), arguments[0] == "codex-config-plan" {
            try printConfigPlan(
                helperPath: arguments[1],
                configPath: arguments.count == 3 ? arguments[2] : nil
            )
            return
        }

        if arguments.count == 2, arguments[0] == "codex-notify" {
            let payload = Data(arguments[1].utf8)
            if let event = try CodexNotifyMapper.map(payload) {
                try write(event, eventRoot: try configuredEventRoot())
                print("Emitted \(event.type.rawValue) as \(event.eventId)")
            } else {
                print("Ignored unsupported Codex notification.")
            }
            return
        }

        if arguments.count == 2, arguments[0] == "codex-app-server" {
            let payload = Data(arguments[1].utf8)
            if let event = try CodexAppServerMapper.map(payload) {
                try write(event, eventRoot: try configuredEventRoot())
                print("Emitted \(event.type.rawValue) as \(event.eventId)")
            } else {
                print("Ignored unsupported App Server notification.")
            }
            return
        }

        guard (1...2).contains(arguments.count) else {
            throw EmitterError.usage
        }

        guard
            let eventType = CompanionEventType(rawValue: arguments[0]),
            ![.integrationHealth, .integrationDisconnected].contains(eventType)
        else {
            throw EmitterError.invalidEventType
        }

        let durationMs: Int64?
        if arguments.count == 2 {
            guard let parsed = Int64(arguments[1]), parsed >= 0 else {
                throw EmitterError.invalidDuration
            }
            durationMs = parsed
        } else {
            durationMs = nil
        }

        let outcome: CompanionEventOutcome?
        switch eventType {
        case .taskCompleted:
            outcome = .success
        case .taskFailed:
            outcome = .failure
        case .taskCancelled:
            outcome = .cancelled
        default:
            outcome = nil
        }

        let event = CompanionEvent(
            source: "codex-skill",
            sourceVersion: "terminal-events-v1",
            type: eventType,
            taskRef: "opaque-\(UUID().uuidString)",
            durationMs: durationMs,
            outcome: outcome
        )
        try write(event, eventRoot: try configuredEventRoot())
        print("Emitted \(event.type.rawValue) as \(event.eventId)")
    }

    private static func printConfigPlan(
        helperPath: String,
        configPath: String?
    ) throws {
        let destination: URL
        if let configPath {
            destination = URL(fileURLWithPath: configPath)
        } else {
            destination = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex/config.toml")
        }
        let existing = try? Data(contentsOf: destination)
        let plan = try CodexNotifyConfigPlanner.plan(
            existingConfig: existing,
            helperPath: helperPath
        )
        print("Status: \(plan.status.rawValue)")
        print("Config: \(destination.path)")
        if plan.status == .appendAtTop {
            print("Proposed line: \(plan.proposedLine)")
            print("No file was changed. Ask the user before applying this line.")
        } else if plan.status == .conflict {
            print("Existing notify configuration detected. No file was changed or displayed.")
            print("Use a user-reviewed wrapper or manual merge; never overwrite it.")
        } else {
            print("The exact helper command is already configured. No file was changed.")
        }
    }

    private static func configuredEventRoot() throws -> URL? {
        guard let path = ProcessInfo.processInfo.environment["CHENGYIN_EVENT_ROOT"] else {
            return nil
        }
        guard path.hasPrefix("/"),
              !path.contains("\n"),
              !path.contains("\r"),
              !path.contains("\0") else {
            throw EmitterError.invalidEventRoot
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }

    private static func write(
        _ event: CompanionEvent,
        eventRoot override: URL?
    ) throws {
        let data = try CompanionEventCodec.encode(event)
        let eventRoot = override ?? FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
                .appendingPathComponent("Chengyin", isDirectory: true)
                .appendingPathComponent("events", isDirectory: true)

        try FileManager.default.createDirectory(
            at: eventRoot,
            withIntermediateDirectories: true
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: eventRoot.path
        )

        let destination = eventRoot.appendingPathComponent(
            "\(event.eventId).json",
            isDirectory: false
        )
        try data.write(to: destination, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: destination.path
        )
    }
}
