import CompanionContracts
import Foundation

private enum SmokeFailure: Error {
    case failed(String)
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw SmokeFailure.failed(message)
    }
}

@main
struct CompanionRelationshipRuntimeSmoke {
    @MainActor
    static func main() throws {
        let suiteName = "cc.chengyin.smoke.relationship-runtime.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SmokeFailure.failed("isolated defaults suite was unavailable")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storageKey = "relationship.primary"
        let backupKey = "relationship.backup"
        let recentKey = "relationship.recent-moments"
        defaults.set((0..<12).map { "moment:\($0)" }, forKey: recentKey)
        let store = CompanionRelationshipStateStore(
            userDefaults: defaults,
            storageKey: storageKey,
            backupKey: backupKey
        )
        let runtime = CompanionRelationshipRuntimeCoordinator(
            store: store,
            defaults: defaults,
            recentMomentKey: recentKey
        )

        try require(runtime.state.bondMoments == 0, "safe initial state was not empty")
        try require(runtime.recentMomentKeyCount == 8, "recent moment history was not bounded")

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let first = try runtime.recordMoment(
            "tap.shared",
            bond: 2,
            chemistry: 1,
            cooldown: 18,
            at: start
        )
        try require(first, "first positive moment was suppressed")
        try require(runtime.state.bondMoments == 2, "positive moment was not persisted")
        try require(runtime.receipt != nil, "relationship feedback was not projected")

        let duplicate = try runtime.recordMoment(
            "tap.shared",
            bond: 2,
            cooldown: 18,
            at: start.addingTimeInterval(5)
        )
        try require(!duplicate, "cooldown duplicate was accepted")
        try require(runtime.state.bondMoments == 2, "cooldown duplicate changed progress")

        for index in 0..<12 {
            _ = try runtime.recordMoment(
                "queue.\(index)",
                bond: 1,
                chemistry: 0,
                advanceSurprise: false,
                cooldown: 0,
                at: start.addingTimeInterval(Double(index + 20))
            )
        }
        try require(runtime.pendingReceiptCount <= 6, "feedback queue exceeded its bound")

        try runtime.update { state in
            state.setToneCap(.romanceLite)
        }
        let played = try runtime.rememberPlayedAsset(
            "cc.fixture.pack:ritual.shared-win",
            at: start
        )
        let readyDuplicate = try runtime.rememberPlayedAsset(
            "cc.fixture.pack:ritual.shared-win",
            at: start.addingTimeInterval(1)
        )
        try require(played && !readyDuplicate, "playback ready debounce failed")
        let selection = runtime.playbackMemory
        try require(
            selection.recentAssetIDs.contains("cc.fixture.pack:ritual.shared-win"),
            "selection context lost opaque playback memory"
        )

        try runtime.forgetMemory(.playbackHistory)
        try require(runtime.state.recentAssetIDs.isEmpty, "playback memory survived explicit deletion")
        try require(runtime.recentMomentKeyCount == 0, "presentation history survived explicit deletion")
        try require(defaults.object(forKey: recentKey) == nil, "recent-key defaults survived deletion")

        runtime.resetTransientFeedbackForTesting()
        try require(runtime.receipt == nil, "transient feedback did not reset")
        try require(runtime.pendingReceiptCount == 0, "queued feedback did not reset")

        try runtime.forgetAllMemory()
        try require(runtime.state.bondMoments == 0, "full deletion preserved shared progress")
        try require(runtime.state.toneCap == .romanceLite, "full deletion lost the explicit tone preference")
        try require(defaults.data(forKey: backupKey) == nil, "rollback data survived explicit deletion")

        print("Relationship runtime coordinator smoke: PASS (10/10)")
    }
}
