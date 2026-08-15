import Foundation

/// App-only projection from private relationship playback memory into the
/// declarative content selector. Selection policy remains in the pack runtime.
extension CompanionRelationshipRuntimeCoordinator {
    func contentSelectionContext(
        at date: Date = Date(),
        recentExclusionLimit: Int = 6
    ) -> ContentPackSelectionContext {
        let memory = playbackMemory
        return ContentPackSelectionContext(
            now: date,
            recentAssetIDs: memory.recentAssetIDs,
            lastPlayedAtByAssetID: memory.lastPlayedAtByAssetID,
            recentExclusionLimit: recentExclusionLimit
        )
    }
}
