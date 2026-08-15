import CoreGraphics
import Foundation

@main
@MainActor
struct MicrogameRuntimeCoordinatorSmoke {
    static func main() async {
        let runtime = CompanionMicrogameRuntimeCoordinator(
            countdownTickNanoseconds: 1_000_000,
            rhythmOpenNanoseconds: 1_000_000,
            rhythmRestNanoseconds: 1_000_000,
            rhythmMinimumIntroDuration: 0
        )

        precondition(runtime.begin(
            .catchPet,
            returnMode: .stage,
            windowOrigin: CGPoint(x: 14, y: 28)
        ))
        precondition(!runtime.begin(.feed, returnMode: .pet))
        for index in 0..<CompanionMicrogameSession.catchTarget {
            let result = runtime.registerCatch(
                at: Date(timeIntervalSince1970: Double(index))
            )
            precondition(
                index == CompanionMicrogameSession.catchTarget - 1
                    ? result == .completed
                    : result == .advanced
            )
        }
        let catchContext = runtime.end(expectedGame: .catchPet)
        precondition(catchContext?.game == .catchPet)
        precondition(catchContext?.presentationMode == .stage)
        precondition(catchContext?.windowOrigin == CGPoint(x: 14, y: 28))
        precondition(!runtime.isActive)
        precondition(runtime.end() == nil)

        precondition(runtime.begin(.feed, returnMode: .pet))
        var expiredGame: CompanionMicrogameKind?
        var initialActionCount = 0
        runtime.startCountdown(
            initialActionDelay: 0.0005,
            onInitialAction: { initialActionCount += 1 },
            onExpired: { game in expiredGame = game }
        )
        for _ in 0..<200 where expiredGame == nil {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        precondition(expiredGame == .feed)
        precondition(initialActionCount == 1)
        precondition(runtime.activeGame == .feed)
        _ = runtime.end(expectedGame: .feed)

        precondition(runtime.begin(.heartTrace, returnMode: .fullscreen))
        var cancelledTimelineFired = false
        runtime.startCountdown { _ in
            cancelledTimelineFired = true
        }
        _ = runtime.end(expectedGame: .heartTrace)
        try? await Task.sleep(nanoseconds: 100_000_000)
        precondition(!cancelledTimelineFired)

        precondition(runtime.begin(.rhythm, returnMode: .pet))
        var openedBeats: [Int] = []
        var rhythmWon: Bool?
        runtime.startRhythmTimeline(
            introDuration: -0.25,
            onBeatOpened: { beat in
                openedBeats.append(beat)
                precondition(runtime.registerRhythmTap(at: Date()) == .advanced)
            },
            onFinished: { won in
                rhythmWon = won
            }
        )
        for _ in 0..<200 where rhythmWon == nil {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        precondition(openedBeats == Array(1...8))
        precondition(rhythmWon == true)
        precondition(runtime.end(expectedGame: .rhythm)?.presentationMode == .pet)

        print(
            "PASS  microgame runtime coordinator: exclusive session, exact return context, "
                + "countdown expiry, cancellation and eight-beat timeline"
        )
    }
}
