import CompanionContracts
import Foundation

private enum SmokeFailure: Error {
    case failed(String)
}

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else { throw SmokeFailure.failed(message) }
}

@main
struct CompanionGestureDiscoveryCoordinatorSmoke {
    @MainActor
    static func main() async throws {
        let suite = "cc.chengyin.smoke.gesture-discovery.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw SmokeFailure.failed("isolated defaults suite was unavailable")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let key = "gesture.discovery.fixture"
        defaults.set(["singleTap", "unknown"], forKey: key)
        let runtime = CompanionGestureDiscoveryCoordinator(
            defaults: defaults,
            storageKey: key,
            hintDelayNanoseconds: 10_000_000
        )

        try require(
            runtime.learnedIDs == ["singleTap"],
            "restart recovery retained an unknown capability"
        )
        try require(runtime.completedCount == 1, "restart recovery lost progress")

        runtime.scheduleIfEligible(true)
        try await Task.sleep(nanoseconds: 30_000_000)
        try require(
            runtime.lesson == .doubleTap,
            "the next one-time lesson was not presented"
        )

        try require(
            runtime.markLearned(.doubleTap),
            "the presented capability was not learned"
        )
        try require(runtime.lesson == nil, "learning did not dismiss the hint")
        try require(
            defaults.stringArray(forKey: key) == ["singleTap", "doubleTap"],
            "learned progress was not persisted in stable order"
        )
        try require(
            !runtime.markLearned(.doubleTap),
            "duplicate learning was accepted"
        )

        runtime.scheduleIfEligible(true)
        runtime.scheduleIfEligible(false)
        try await Task.sleep(nanoseconds: 30_000_000)
        try require(runtime.lesson == nil, "an ineligible delayed hint survived cancellation")

        runtime.replaceLearnedIDs(["drag", "longPress", "invalid"])
        try require(
            runtime.learnedIDs == ["longPress", "drag"],
            "backup restore did not canonicalize capability identifiers"
        )

        runtime.reset()
        try require(runtime.completedCount == 0, "explicit reset retained progress")
        try require(defaults.object(forKey: key) == nil, "explicit reset retained storage")

        print("Gesture discovery coordinator smoke: PASS (9/9)")
    }
}
