import Foundation

private struct SmokeFailure: Error, CustomStringConvertible {
    let description: String
}

@MainActor
private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else { throw SmokeFailure(description: message) }
}

@main
@MainActor
private struct CompanionPetFeedbackRuntimeCoordinatorSmoke {
    static func main() async throws {
        let runtime = CompanionPetFeedbackRuntimeCoordinator()
        try require(runtime.mood == .calm, "Initial mood was not calm")
        try require(runtime.pose == .neutral, "Initial pose was not neutral")
        try require(runtime.effect == nil, "Initial effect was not empty")

        runtime.setPose(PetPose(x: 4, y: 2, rotation: 3, scale: 1.1))
        runtime.schedulePoseReset(after: 0.04)
        try? await Task.sleep(nanoseconds: 10_000_000)
        let newerPose = PetPose(x: -3, y: 1, rotation: -2, scale: 1.04)
        runtime.setPose(newerPose)
        try? await Task.sleep(nanoseconds: 55_000_000)
        try require(
            runtime.pose == newerPose,
            "An older pose reset overwrote a newer interaction"
        )

        runtime.schedulePoseReset(after: 0.02)
        try? await Task.sleep(nanoseconds: 35_000_000)
        try require(runtime.pose == .neutral, "Current pose reset did not settle")

        runtime.setMood(.playful)
        runtime.scheduleMoodReset(after: 0.02, isEligible: { false })
        try? await Task.sleep(nanoseconds: 35_000_000)
        try require(
            runtime.mood == .playful,
            "Ineligible mood reset changed an occupied interaction"
        )

        runtime.scheduleMoodReset(after: 0.02, isEligible: { true })
        try? await Task.sleep(nanoseconds: 35_000_000)
        try require(runtime.mood == .calm, "Eligible mood reset did not settle")

        runtime.presentEffect(symbol: "a", text: "older", for: 0.04)
        try? await Task.sleep(nanoseconds: 10_000_000)
        runtime.presentEffect(symbol: "b", text: "newer", for: 0.09)
        try? await Task.sleep(nanoseconds: 45_000_000)
        try require(
            runtime.effect?.text == "newer",
            "An older effect expiry cleared a newer effect"
        )
        try? await Task.sleep(nanoseconds: 60_000_000)
        try require(runtime.effect == nil, "Current effect did not expire")

        runtime.setMood(.affectionate)
        runtime.setPose(newerPose)
        runtime.presentEffect(symbol: "c", text: "cancelled", for: 0.02)
        runtime.scheduleMoodReset(after: 0.02, isEligible: { true })
        runtime.schedulePoseReset(after: 0.02)
        runtime.cancelAll()
        try? await Task.sleep(nanoseconds: 35_000_000)
        try require(
            runtime.mood == .affectionate && runtime.pose == newerPose,
            "Explicit cancellation did not preserve current feedback values"
        )
        try require(runtime.effect == nil, "Explicit cancellation retained an effect")

        runtime.setMood(.curious)
        runtime.scheduleMoodReset(after: .infinity, isEligible: { true })
        try require(
            runtime.mood == .calm,
            "Non-finite reset delay did not use the bounded immediate fallback"
        )
        runtime.setPose(newerPose)
        runtime.schedulePoseReset(after: .nan)
        try require(
            runtime.pose == .neutral,
            "Non-finite pose delay did not use the bounded immediate fallback"
        )
        runtime.presentEffect(symbol: "d", text: "invalid", for: .infinity)
        try require(
            runtime.effect == nil,
            "Non-finite effect duration did not use the bounded immediate fallback"
        )

        print(
            "Pet feedback runtime coordinator smoke: PASS "
                + "(generation-safe pose, mood and effect lifetimes)"
        )
    }
}
