import CompanionContracts

extension CompanionViewModel {
    /// Commits one visible reward after media selection has started, while
    /// preserving the exact pre-game mode for final restoration.
    func commitGameRewardPresentation(
        _ returnMode: CompanionDisplayMode,
        _ restorePreviousMode: Bool
    ) {
        let directive = presentationRuntime.commitGameReward(
            returnMode: returnMode.presentationMode,
            restorePreviousMode: restorePreviousMode,
            audiovisualEnabled: playbackMode == .audioVisual
        )
        applyPresentationDirective(directive)
    }
}
