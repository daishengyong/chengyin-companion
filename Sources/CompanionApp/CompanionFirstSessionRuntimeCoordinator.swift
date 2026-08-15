import Combine
#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Foundation

enum CompanionWorkArcPreviewBeat: String, Equatable, Sendable {
    case idle
    case started
    case progress
    case longRunning
    case completed
}

struct CompanionWorkArcPreviewTiming: Equatable, Sendable {
    let progressDelay: TimeInterval
    let longRunningDelay: TimeInterval
    let completionDelay: TimeInterval

    static let standard = CompanionWorkArcPreviewTiming(
        progressDelay: 1.4,
        longRunningDelay: 1.4,
        completionDelay: 1.8
    )
}

/// Owns only first-session state and cancellable preview timing.
///
/// Persistence, media, speech, windows and task content remain outside this
/// coordinator. Generation checks prevent a stale preview from completing a
/// newer replay.
@MainActor
final class CompanionFirstSessionRuntimeCoordinator: ObservableObject {
    @Published private(set) var journey = CompanionFirstSessionJourney()
    @Published private(set) var workArcBeat: CompanionWorkArcPreviewBeat = .idle

    private let timing: CompanionWorkArcPreviewTiming
    private var workArcTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    init(timing: CompanionWorkArcPreviewTiming = .standard) {
        self.timing = timing
    }

    deinit {
        workArcTask?.cancel()
    }

    var isActive: Bool { journey.isActive }

    @discardableResult
    func begin() -> CompanionFirstSessionEffect {
        cancelWorkArc()
        return journey.handle(.begin).effect
    }

    @discardableResult
    func replay() -> CompanionFirstSessionEffect {
        cancelWorkArc()
        return journey.handle(.replay).effect
    }

    @discardableResult
    func recordSingleTap() -> CompanionFirstSessionEffect {
        journey.handle(.singleTap).effect
    }

    @discardableResult
    func recordDoubleTap() -> CompanionFirstSessionEffect {
        journey.handle(.doubleTap).effect
    }

    @discardableResult
    func selectPreference(
        _ preference: CompanionFirstSessionPreference
    ) -> CompanionFirstSessionEffect {
        journey.handle(.selectPreference(preference)).effect
    }

    @discardableResult
    func skip() -> CompanionFirstSessionEffect {
        cancelWorkArc()
        return journey.handle(.skip).effect
    }

    func runWorkArc(
        onBeat: @escaping @MainActor (CompanionWorkArcPreviewBeat) -> Void
    ) {
        cancelWorkArc()
        generation &+= 1
        if generation == 0 { generation = 1 }
        let token = generation
        publish(.started, onBeat: onBeat)

        workArcTask = Task { [weak self] in
            guard let self else { return }
            await self.pause(self.timing.progressDelay)
            guard !Task.isCancelled, self.generation == token else { return }
            self.publish(.progress, onBeat: onBeat)

            await self.pause(self.timing.longRunningDelay)
            guard !Task.isCancelled, self.generation == token else { return }
            self.publish(.longRunning, onBeat: onBeat)

            await self.pause(self.timing.completionDelay)
            guard !Task.isCancelled, self.generation == token else { return }
            self.workArcTask = nil
            self.publish(.completed, onBeat: onBeat)
        }
    }

    func completeJourneyAfterWorkArc() -> CompanionFirstSessionEffect {
        journey.handle(.workArcCompleted).effect
    }

    func cancelWorkArc() {
        workArcTask?.cancel()
        workArcTask = nil
        generation &+= 1
        workArcBeat = .idle
    }

    private func publish(
        _ beat: CompanionWorkArcPreviewBeat,
        onBeat: @escaping @MainActor (CompanionWorkArcPreviewBeat) -> Void
    ) {
        workArcBeat = beat
        onBeat(beat)
    }

    private func pause(_ duration: TimeInterval) async {
        let bounded = duration.isFinite ? min(max(duration, 0), 60) : 60
        try? await Task.sleep(
            nanoseconds: UInt64(bounded * 1_000_000_000)
        )
    }
}
