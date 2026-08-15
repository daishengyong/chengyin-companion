import Combine
import Foundation

/// Owns ephemeral pet mood, pose and effect lifetimes.
///
/// Every new value invalidates an older scheduled reset, so a stale hover,
/// drag or effect timer cannot overwrite a newer interaction. The coordinator
/// intentionally owns no windows, media, speech, persistence or task content.
@MainActor
final class CompanionPetFeedbackRuntimeCoordinator: ObservableObject {
    @Published private(set) var mood: PetMood = .calm
    @Published private(set) var pose: PetPose = .neutral
    @Published private(set) var effect: PetEffect?

    private var poseResetTask: Task<Void, Never>?
    private var moodResetTask: Task<Void, Never>?
    private var effectExpiryTask: Task<Void, Never>?
    private var poseGeneration: UInt64 = 0
    private var moodGeneration: UInt64 = 0
    private var effectGeneration: UInt64 = 0

    deinit {
        poseResetTask?.cancel()
        moodResetTask?.cancel()
        effectExpiryTask?.cancel()
    }

    func setMood(_ mood: PetMood) {
        cancelMoodReset()
        self.mood = mood
    }

    func setPose(_ pose: PetPose) {
        cancelPoseReset()
        self.pose = pose
    }

    func updatePose(_ update: (inout PetPose) -> Void) {
        cancelPoseReset()
        update(&pose)
    }

    func presentEffect(
        symbol: String,
        text: String,
        for duration: TimeInterval = 1.65
    ) {
        cancelEffectExpiry(clear: false)
        effect = PetEffect(symbol: symbol, text: text)
        guard duration.isFinite else {
            effect = nil
            return
        }
        let generation = effectGeneration
        effectExpiryTask = Task { [weak self] in
            await Self.wait(for: duration)
            guard !Task.isCancelled,
                  let self,
                  self.effectGeneration == generation
            else { return }
            self.effect = nil
            self.effectExpiryTask = nil
        }
    }

    func schedulePoseReset(after delay: TimeInterval) {
        cancelPoseReset()
        guard delay.isFinite else {
            pose = .neutral
            return
        }
        let generation = poseGeneration
        poseResetTask = Task { [weak self] in
            await Self.wait(for: delay)
            guard !Task.isCancelled,
                  let self,
                  self.poseGeneration == generation
            else { return }
            self.pose = .neutral
            self.poseResetTask = nil
        }
    }

    func scheduleMoodReset(
        after delay: TimeInterval,
        isEligible: @escaping @MainActor () -> Bool
    ) {
        cancelMoodReset()
        guard delay.isFinite else {
            if isEligible() { mood = .calm }
            return
        }
        let generation = moodGeneration
        moodResetTask = Task { [weak self] in
            await Self.wait(for: delay)
            guard !Task.isCancelled,
                  let self,
                  self.moodGeneration == generation,
                  isEligible()
            else { return }
            self.mood = .calm
            self.moodResetTask = nil
        }
    }

    func cancelPoseReset() {
        poseGeneration &+= 1
        poseResetTask?.cancel()
        poseResetTask = nil
    }

    func cancelMoodReset() {
        moodGeneration &+= 1
        moodResetTask?.cancel()
        moodResetTask = nil
    }

    func cancelAll() {
        cancelPoseReset()
        cancelMoodReset()
        cancelEffectExpiry(clear: true)
    }

    private func cancelEffectExpiry(clear: Bool) {
        effectGeneration &+= 1
        effectExpiryTask?.cancel()
        effectExpiryTask = nil
        if clear {
            effect = nil
        }
    }

    private static func wait(for delay: TimeInterval) async {
        let seconds = min(max(delay, 0), 60)
        if seconds == 0 {
            await Task.yield()
            return
        }
        try? await Task.sleep(
            nanoseconds: UInt64(seconds * 1_000_000_000)
        )
    }
}
