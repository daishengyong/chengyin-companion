import Foundation

@main
@MainActor
struct ExperienceRuntimeCoordinatorSmoke {
    static func main() async {
        let runtime = CompanionExperienceRuntimeCoordinator<String>(
            normalCapacity: 2,
            trustedCapacity: 3,
            attentionPolicy: CompanionAttentionPolicy(
                postUserInteractionSilence: 45,
                responseReadyCooldown: 0,
                responseReadyLimitPerHour: 4,
                proactiveLimitPerHour: 4
            )
        )
        let directPlayAt = Date(timeIntervalSince1970: 900)
        runtime.noteUserInitiated(at: directPlayAt)
        let afterDirectPlay = CompanionExperienceContext(
            now: directPlayAt.addingTimeInterval(15),
            isDirectInteractionActive: false,
            isGameplayActive: false,
            isMediaPlaybackActive: false,
            isSpeaking: false,
            isQuietHours: false
        )
        precondition(
            runtime.decide(for: .proactiveCare, context: afterDirectPlay)
                == .deferUntilNextEvaluation(reason: .recentUserInteraction)
        )
        precondition(
            runtime.decide(for: .responseReady, context: afterDirectPlay)
                == .ambientOnly(reason: .recentUserInteraction)
        )
        precondition(
            runtime.decide(for: .trustedTaskTerminal, context: afterDirectPlay)
                == .present
        )
        let busy = CompanionExperienceContext(
            now: Date(timeIntervalSince1970: 1_000),
            isDirectInteractionActive: true,
            isGameplayActive: false,
            isMediaPlaybackActive: false,
            isSpeaking: false,
            isQuietHours: false
        )
        precondition(
            runtime.decide(for: .trustedTaskTerminal, context: busy)
                == .enqueue(reason: .presentationBusy)
        )

        precondition(runtime.enqueue(
            event: "reply",
            completionContext: nil,
            source: .responseReady
        ).outcome == .accepted)
        precondition(runtime.enqueue(
            event: "complete-1",
            completionContext: nil,
            source: .trustedTaskTerminal
        ).outcome == .accepted)
        precondition(runtime.enqueue(
            event: "complete-2",
            completionContext: nil,
            source: .trustedTaskTerminal
        ).outcome == .replacedLowerPriority)
        precondition(runtime.pendingCount == 2)
        precondition(runtime.enqueue(
            event: "complete-3",
            completionContext: nil,
            source: .trustedTaskTerminal
        ).outcome == .acceptedTrustedOverflow)
        precondition(runtime.enqueue(
            event: "complete-3",
            completionContext: nil,
            source: .trustedTaskTerminal
        ).outcome == .coalescedTrustedTerminal)
        precondition(runtime.pendingCount == 3)
        precondition(runtime.enqueue(
            event: "stale-time-announcement",
            completionContext: nil,
            source: .proactiveCare
        ).outcome == .rejectedCapacity)

        let directQueue = CompanionExperienceRuntimeCoordinator<String>()
        _ = directQueue.enqueue(
            event: "stale-time-announcement",
            completionContext: nil,
            source: .proactiveCare
        )
        _ = directQueue.enqueue(
            event: "trusted-completion",
            completionContext: nil,
            source: .trustedTaskTerminal
        )
        precondition(directQueue.discardPending(source: .proactiveCare) == 1)
        precondition(directQueue.pendingCount == 1)
        precondition(directQueue.dequeue()?.event == "trusted-completion")

        var finished: [String] = []
        let stale = runtime.beginPresentation()
        precondition(runtime.scheduleFinish(for: stale, after: 0.02) { _ in
            finished.append("stale")
        })
        let current = runtime.beginPresentation()
        precondition(runtime.scheduleFinish(for: current, after: 0.001) { _ in
            finished.append("current")
        })
        for _ in 0..<100 where finished.isEmpty {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        precondition(finished == ["current"])
        precondition(!runtime.isPresentationActive)

        let cancelled = runtime.beginPresentation()
        precondition(runtime.scheduleFinish(for: cancelled, after: 0.001) { _ in
            finished.append("cancelled")
        })
        runtime.cancelPresentation()
        try? await Task.sleep(nanoseconds: 20_000_000)
        precondition(finished == ["current"])

        var handoffs = 0
        runtime.scheduleHandoff(
            after: 0.01,
            isValid: { true },
            onReady: { handoffs += 1 }
        )
        let interruptsHandoff = runtime.beginPresentation()
        precondition(runtime.completePresentation(token: interruptsHandoff))
        try? await Task.sleep(nanoseconds: 25_000_000)
        precondition(handoffs == 0)
        runtime.scheduleHandoff(
            after: 0,
            isValid: { true },
            onReady: { handoffs += 1 }
        )
        for _ in 0..<100 where handoffs == 0 {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        precondition(handoffs == 1)

        var delivered: [CompanionPendingExperience<String>] = []
        runtime.schedulePendingDelivery(
            after: 0,
            isReady: { false },
            onReady: { delivered.append($0) }
        )
        try? await Task.sleep(nanoseconds: 10_000_000)
        precondition(delivered.isEmpty)
        precondition(runtime.pendingCount == 3)
        runtime.schedulePendingDelivery(
            after: 0,
            isReady: { true },
            onReady: { delivered.append($0) }
        )
        for _ in 0..<100 where delivered.isEmpty {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        precondition(delivered.count == 1)
        precondition(delivered[0].source == .trustedTaskTerminal)
        precondition(runtime.pendingCount == 2)

        print(
            "PASS  experience runtime coordinator: arbitration, trusted overflow, "
                + "post-user-interaction attention grace, generation-safe finish, "
                + "stale proactive-cue discard, stale-handoff cancellation and readiness replay"
        )
    }
}
