import Combine
#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import CoreGraphics
import Foundation

struct CompanionMicrogameReturnContext: Equatable {
    let game: CompanionMicrogameKind
    let presentationMode: CompanionPresentationMode
    let windowOrigin: CGPoint?
}

/// Owns the ephemeral runtime surrounding the deterministic Core game session.
///
/// The coordinator deliberately does not know about AppKit windows, media,
/// speech, haptics, relationship rewards or persistence. It guarantees one
/// active game, one cancellable timeline and one exact return context. The
/// view model maps emitted events to presentation side effects.
@MainActor
final class CompanionMicrogameRuntimeCoordinator: ObservableObject {
    @Published private(set) var session = CompanionMicrogameSession()

    private let countdownTickNanoseconds: UInt64
    private let rhythmOpenNanoseconds: UInt64
    private let rhythmRestNanoseconds: UInt64
    private let rhythmMinimumIntroDuration: TimeInterval
    private var timelineTask: Task<Void, Never>?
    private var returnContext: CompanionMicrogameReturnContext?

    init(
        countdownTickNanoseconds: UInt64 = 1_000_000_000,
        rhythmOpenNanoseconds: UInt64 = 480_000_000,
        rhythmRestNanoseconds: UInt64 = 470_000_000,
        rhythmMinimumIntroDuration: TimeInterval = 1.4
    ) {
        self.countdownTickNanoseconds = max(1, countdownTickNanoseconds)
        self.rhythmOpenNanoseconds = max(1, rhythmOpenNanoseconds)
        self.rhythmRestNanoseconds = max(1, rhythmRestNanoseconds)
        self.rhythmMinimumIntroDuration = max(0, rhythmMinimumIntroDuration)
    }

    deinit {
        timelineTask?.cancel()
    }

    var activeGame: CompanionMicrogameKind? { session.activeGame }
    var isActive: Bool { activeGame != nil }

    @discardableResult
    func begin(
        _ game: CompanionMicrogameKind,
        returnMode: CompanionPresentationMode,
        windowOrigin: CGPoint? = nil
    ) -> Bool {
        guard !isActive else { return false }
        timelineTask?.cancel()
        timelineTask = nil
        session.start(game)
        returnContext = CompanionMicrogameReturnContext(
            game: game,
            presentationMode: returnMode,
            windowOrigin: windowOrigin
        )
        return true
    }

    /// Starts the single timer used by every countdown-driven game.
    func startCountdown(
        initialActionDelay: TimeInterval? = nil,
        onInitialAction: (@MainActor () -> Void)? = nil,
        onExpired: @escaping @MainActor (CompanionMicrogameKind) -> Void
    ) {
        guard let expectedGame = activeGame,
              expectedGame != .rhythm
        else { return }

        replaceTimeline { [weak self] in
            var isFirstTick = true
            while !Task.isCancelled {
                guard let self else { return }
                if isFirstTick,
                   let initialActionDelay,
                   let onInitialAction {
                    let boundedDelay = min(
                        max(0, initialActionDelay),
                        Double(self.countdownTickNanoseconds) / 1_000_000_000
                    )
                    let initialNanoseconds = UInt64(
                        boundedDelay * 1_000_000_000
                    )
                    if initialNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: initialNanoseconds)
                    }
                    guard !Task.isCancelled,
                          self.activeGame == expectedGame
                    else { return }
                    onInitialAction()
                    let remainingNanoseconds =
                        self.countdownTickNanoseconds - initialNanoseconds
                    if remainingNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: remainingNanoseconds)
                    }
                } else {
                    try? await Task.sleep(
                        nanoseconds: self.countdownTickNanoseconds
                    )
                }
                isFirstTick = false
                guard !Task.isCancelled,
                      self.activeGame == expectedGame
                else { return }
                if self.session.tick() {
                    onExpired(expectedGame)
                    return
                }
            }
        }
    }

    /// Runs the eight visible rhythm windows on the same exclusive timeline.
    func startRhythmTimeline(
        introDuration: TimeInterval,
        onBeatOpened: @escaping @MainActor (Int) -> Void,
        onFinished: @escaping @MainActor (Bool) -> Void
    ) {
        guard activeGame == .rhythm else { return }
        let leadDuration = max(
            introDuration + 0.25,
            rhythmMinimumIntroDuration
        )
        let leadNanoseconds = UInt64(leadDuration * 1_000_000_000)

        replaceTimeline { [weak self] in
            if leadNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: leadNanoseconds)
            }
            guard let self, !Task.isCancelled,
                  self.activeGame == .rhythm
            else { return }

            for beat in 1...CompanionMicrogameSession.rhythmBeatCount {
                guard !Task.isCancelled, self.activeGame == .rhythm else {
                    return
                }
                self.session.beginRhythmBeat(beat, at: Date())
                onBeatOpened(beat)

                try? await Task.sleep(
                    nanoseconds: self.rhythmOpenNanoseconds
                )
                guard !Task.isCancelled, self.activeGame == .rhythm else {
                    return
                }
                self.session.closeRhythmBeat()

                try? await Task.sleep(
                    nanoseconds: self.rhythmRestNanoseconds
                )
            }

            guard !Task.isCancelled, self.activeGame == .rhythm else { return }
            onFinished(self.session.rhythmDidWin)
        }
    }

    @discardableResult
    func end(
        expectedGame: CompanionMicrogameKind? = nil
    ) -> CompanionMicrogameReturnContext? {
        guard let activeGame,
              expectedGame == nil || expectedGame == activeGame
        else { return nil }
        timelineTask?.cancel()
        timelineTask = nil
        let context = returnContext
        returnContext = nil
        session.end()
        return context
    }

    func registerCatch(at date: Date) -> CompanionMicrogameInputOutcome {
        session.registerCatch(at: date)
    }

    func registerHideFind(at date: Date) -> CompanionMicrogameInputOutcome {
        session.registerHideFind(at: date)
    }

    func registerComboGesture(
        _ gesture: CompanionMicrogameGesture
    ) -> CompanionMicrogameInputOutcome {
        session.registerComboGesture(gesture)
    }

    func registerHeartPoint(
        _ point: CompanionNormalizedPoint
    ) -> CompanionMicrogameInputOutcome {
        session.registerHeartPoint(point)
    }

    func resetHeartTrace() {
        session.resetHeartTrace()
    }

    func registerRhythmTap(at date: Date) -> CompanionMicrogameInputOutcome {
        session.registerRhythmTap(at: date)
    }

    func registerRhythmMiss() -> CompanionMicrogameInputOutcome {
        session.registerRhythmMiss()
    }

    func registerFeedSuccess() -> CompanionMicrogameInputOutcome {
        session.registerFeedSuccess()
    }

    private func replaceTimeline(
        _ operation: @escaping @MainActor () async -> Void
    ) {
        timelineTask?.cancel()
        timelineTask = Task { @MainActor in
            await operation()
        }
    }
}
