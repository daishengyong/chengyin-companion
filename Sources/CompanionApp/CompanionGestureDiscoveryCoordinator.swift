import Combine
import CompanionContracts
import Foundation

/// Owns the restart-safe, one-time desktop-pet gesture coach.
///
/// Persisted state is limited to the four opaque capability identifiers. The
/// coordinator never receives pointer coordinates, task content, media, window,
/// speech or network capability. The view model supplies only a bounded
/// eligibility fact for presenting the next lesson.
@MainActor
final class CompanionGestureDiscoveryCoordinator: ObservableObject {
    @Published private(set) var lesson: CompanionGestureCapability?

    private let defaults: UserDefaults
    private let storageKey: String
    private let hintDelayNanoseconds: UInt64
    private var learningState: CompanionGestureLearningState
    private var hintTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = CompanionDefaultsKeys.learnedPetGestures,
        hintDelayNanoseconds: UInt64 = 650_000_000
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.hintDelayNanoseconds = hintDelayNanoseconds
        learningState = CompanionGestureLearningState(
            learnedIDs: defaults.stringArray(forKey: storageKey) ?? []
        )
    }

    deinit {
        hintTask?.cancel()
    }

    var learnedIDs: [String] { learningState.learnedIDs }
    var completedCount: Int { learningState.completedCount }
    var totalCount: Int { learningState.totalCount }

    @discardableResult
    func markLearned(_ capability: CompanionGestureCapability) -> Bool {
        guard learningState.markLearned(capability) else { return false }
        persist()
        cancelPendingLesson()
        return true
    }

    func replaceLearnedIDs(_ identifiers: [String]) {
        learningState = CompanionGestureLearningState(learnedIDs: identifiers)
        persist()
        cancelPendingLesson()
    }

    func reset() {
        learningState.reset()
        defaults.removeObject(forKey: storageKey)
        cancelPendingLesson()
    }

    func scheduleIfEligible(_ eligible: Bool) {
        guard eligible else {
            cancelPendingLesson()
            return
        }
        guard hintTask == nil,
              lesson == nil,
              let nextLesson = learningState.nextLesson
        else { return }

        hintTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: hintDelayNanoseconds)
            guard !Task.isCancelled else { return }
            guard learningState.nextLesson == nextLesson else {
                hintTask = nil
                return
            }
            lesson = nextLesson
            hintTask = nil
        }
    }

    func cancelPendingLesson() {
        hintTask?.cancel()
        hintTask = nil
        lesson = nil
    }

    private func persist() {
        defaults.set(learningState.learnedIDs, forKey: storageKey)
    }
}
