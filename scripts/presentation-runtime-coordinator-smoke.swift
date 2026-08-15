import CompanionContracts
import Foundation

private enum SmokeFailure: Error { case failed(String) }

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else { throw SmokeFailure.failed(message) }
}

@main
struct CompanionPresentationRuntimeCoordinatorSmoke {
    static func main() throws {
        var runtime = CompanionPresentationRuntimeCoordinator()

        let clickPlan = runtime.plan(
            for: .petInteraction,
            currentMode: .pet,
            audiovisualEnabled: true
        )
        let click = runtime.beginDirectUserPlan(clickPlan)
        try require(click.targetMode == .stage, "pet click did not expand")
        try require(click.directUserOwnsReturn, "pet click lost return ownership")
        try require(
            runtime.finish(continuesIntoFallback: true) == nil,
            "generated-media fallback restored too early"
        )
        try require(runtime.finish() == .pet, "pet click did not restore exactly")

        let audioOnly = runtime.plan(
            for: .magicWand,
            currentMode: .pet,
            audiovisualEnabled: false
        )
        try require(audioOnly == .unchanged, "audio-only play expanded a window")

        let automatic = runtime.beginAutomaticResponse(currentMode: .pet)
        try require(automatic.targetMode == .stage, "automatic cue did not open pet")
        try require(runtime.finish() == .pet, "automatic cue did not restore pet")

        let remain = runtime.beginContentSequence(
            returnPolicy: .remainExpanded,
            currentMode: .pet,
            directPlan: nil
        )
        try require(remain.targetMode == .stage, "remain-expanded content stayed tiny")
        try require(runtime.finish() == nil, "remain-expanded content invented a return")

        let rewardPlan = runtime.plan(
            for: .gameReward,
            currentMode: .pet,
            audiovisualEnabled: true
        )
        _ = runtime.beginDirectUserPlan(rewardPlan)
        let reward = runtime.commitGameReward(
            returnMode: .stage,
            restorePreviousMode: true,
            audiovisualEnabled: true
        )
        try require(reward.targetMode == .fullscreen, "game reward was not fullscreen")
        try require(runtime.finish() == .stage, "game reward lost exact pre-game mode")

        _ = runtime.beginDirectUserPlan(rewardPlan)
        _ = runtime.commitGameReward(
            returnMode: .stage,
            restorePreviousMode: false,
            audiovisualEnabled: true
        )
        try require(runtime.finish() == .pet, "non-restoring game did not return to pet")

        _ = runtime.beginAutomaticResponse(currentMode: .pet)
        runtime.reset()
        try require(runtime.finish() == nil, "explicit reset retained a stale return")

        let silentReward = runtime.commitGameReward(
            returnMode: .stage,
            restorePreviousMode: true,
            audiovisualEnabled: false
        )
        try require(silentReward.targetMode == nil, "audio-only reward expanded a window")

        print("Presentation runtime coordinator smoke: PASS (12/12)")
    }
}
