import Foundation

@main
@MainActor
struct FirstSessionRuntimeCoordinatorSmoke {
    static func main() async {
        let runtime = CompanionFirstSessionRuntimeCoordinator(
            timing: CompanionWorkArcPreviewTiming(
                progressDelay: 0.006,
                longRunningDelay: 0.006,
                completionDelay: 0.006
            )
        )

        precondition(runtime.begin() == .presentCoach)
        precondition(runtime.recordDoubleTap() == .none)
        precondition(runtime.recordSingleTap() == .acknowledgeInteraction)
        precondition(runtime.recordDoubleTap() == .acknowledgeInteraction)
        precondition(
            runtime.selectPreference(.workCompanion)
                == .applyPreferenceAndRunWorkArc(.workCompanion)
        )

        var beats: [CompanionWorkArcPreviewBeat] = []
        runtime.runWorkArc { beats.append($0) }
        for _ in 0..<100 where beats.last != .completed {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        precondition(beats == [.started, .progress, .longRunning, .completed])
        precondition(runtime.completeJourneyAfterWorkArc() == .complete)
        precondition(!runtime.isActive)

        var replayBeats: [CompanionWorkArcPreviewBeat] = []
        runtime.runWorkArc { replayBeats.append($0) }
        try? await Task.sleep(nanoseconds: 3_000_000)
        runtime.runWorkArc { replayBeats.append($0) }
        for _ in 0..<100 where replayBeats.last != .completed {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        precondition(replayBeats.filter { $0 == .completed }.count == 1)
        precondition(runtime.workArcBeat == .completed)

        runtime.runWorkArc { _ in }
        runtime.cancelWorkArc()
        try? await Task.sleep(nanoseconds: 30_000_000)
        precondition(runtime.workArcBeat == .idle)

        print(
            "PASS  first-session runtime: ordered journey, deterministic beats, "
                + "stale-preview cancellation and explicit replay"
        )
    }
}
