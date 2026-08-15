import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL  \(message)\n", stderr)
        exit(1)
    }
}

@main
private struct WorkDirectorSmoke {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var director = CompanionWorkDirector()

        require(
            director.consume(
                type: .taskStarted,
                eventID: "start-1",
                taskRef: "opaque-1",
                duration: 0,
                occurredAt: start
            ) == .focusStarted,
            "task start did not enter focus"
        )

        require(
            director.consume(
                type: .taskLongRunning,
                eventID: "long-1",
                taskRef: "opaque-1",
                duration: 0,
                occurredAt: start.addingTimeInterval(12 * 60)
            ) == .longRunning(elapsed: 12 * 60),
            "long-running elapsed time was not derived"
        )

        require(
            director.consume(
                type: .responseReady,
                eventID: "turn-ready-1",
                taskRef: "opaque-1",
                duration: 0,
                occurredAt: start.addingTimeInterval(13 * 60)
            ) == .responseReady,
            "response boundary was not neutral"
        )
        require(director.hasActiveWork, "response boundary ended active work")
        require(
            CompanionWorkdaySignalTrustPolicy.effectiveType(
                requestedType: .taskCompleted,
                outcome: .success,
                origin: .legacyTurnBoundary
            ) == .responseReady,
            "legacy turn boundary became a completion"
        )
        require(
            CompanionWorkdaySignalTrustPolicy.effectiveType(
                requestedType: .taskCompleted,
                outcome: .success,
                origin: .explicitProtocol
            ) == .responseReady,
            "unregistered local producer became a completion"
        )
        require(
            CompanionWorkdaySignalTrustPolicy.effectiveType(
                requestedType: .taskCompleted,
                outcome: .success,
                origin: .companionTerminalEmitter
            ) == .taskCompleted,
            "bundled terminal emitter lost completion trust"
        )

        let firstCompletion = director.consume(
            type: .taskCompleted,
            eventID: "done-1",
            taskRef: "opaque-1",
            duration: 0,
            occurredAt: start.addingTimeInterval(14 * 60)
        )
        guard case let .completed(firstContext) = firstCompletion else {
            fputs("FAIL  task completion did not produce context\n", stderr)
            exit(1)
        }
        require(firstContext.duration == 14 * 60, "completion duration was not derived")
        require(firstContext.tier == .playful, "long task should receive playful tier")

        _ = director.consume(
            type: .taskFailed,
            eventID: "failed-1",
            taskRef: "opaque-2",
            duration: 30,
            occurredAt: start.addingTimeInterval(15 * 60)
        )
        let recovery = director.consume(
            type: .taskCompleted,
            eventID: "done-2",
            taskRef: "opaque-2",
            duration: 90,
            occurredAt: start.addingTimeInterval(17 * 60)
        )
        guard case let .completed(recoveryContext) = recovery else {
            fputs("FAIL  recovery completion did not produce context\n", stderr)
            exit(1)
        }
        require(recoveryContext.recoveredAfterFailure, "recovery was not remembered")
        require(recoveryContext.tier == .signature, "recovery should be signature tier")
        let presentation = CompanionWorkdayExperiencePolicy.plan(
            for: recovery,
            context: CompanionWorkdayPresentationContext(
                allowsPassivePresenceUpdate: false,
                hasActiveWork: false,
                completionReplyWindowActive: false
            )
        )
        require(
            presentation.event == .taskComplete(recoveryContext),
            "completion did not reach the unified presentation plan"
        )
        require(
            presentation.relationshipReward?.milestones.contains(
                .recoveredAfterFailure
            ) == true,
            "recovery milestone was not projected"
        )

        print("PASS  work director lifecycle")
        print("PASS  duration derivation")
        print("PASS  recovery celebration")
        print("PASS  workday trust and presentation policy")
    }
}
