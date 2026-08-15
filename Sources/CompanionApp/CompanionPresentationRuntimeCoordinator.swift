import CompanionContracts

/// Owns the side-effect-free expansion and exact-restoration session shared by
/// pet clicks, magic-wand choices, content-pack fallback and game rewards.
///
/// The coordinator receives only semantic modes and intent. It owns no window,
/// media, timer, speech, task-content, persistence or network capability; the
/// view model remains responsible only for applying returned directives.
struct CompanionPresentationRuntimeCoordinator {
    private let userPolicy = CompanionUserPresentationPolicy()
    private var lifecycle = CompanionPresentationLifecycle()

    func plan(
        for intent: CompanionUserPresentationIntent,
        currentMode: CompanionPresentationMode,
        audiovisualEnabled: Bool
    ) -> CompanionUserPresentationPlan {
        userPolicy.plan(
            for: intent,
            currentMode: currentMode,
            audiovisualEnabled: audiovisualEnabled
        )
    }

    mutating func beginDirectUserPlan(
        _ plan: CompanionUserPresentationPlan
    ) -> CompanionPresentationDirective {
        lifecycle.beginDirectUserPlan(plan)
    }

    mutating func beginAutomaticResponse(
        currentMode: CompanionPresentationMode
    ) -> CompanionPresentationDirective {
        lifecycle.beginAutomaticResponse(currentMode: currentMode)
    }

    mutating func beginContentSequence(
        returnPolicy: CompanionPresentationContentReturnPolicy,
        currentMode: CompanionPresentationMode,
        directPlan: CompanionUserPresentationPlan?
    ) -> CompanionPresentationDirective {
        lifecycle.beginContentSequence(
            returnPolicy: returnPolicy,
            currentMode: currentMode,
            directPlan: directPlan
        )
    }

    mutating func commitGameReward(
        returnMode: CompanionPresentationMode,
        restorePreviousMode: Bool,
        audiovisualEnabled: Bool
    ) -> CompanionPresentationDirective {
        guard audiovisualEnabled else {
            return CompanionPresentationDirective(targetMode: nil)
        }
        lifecycle.setDirectReturnMode(
            restorePreviousMode ? returnMode : .pet
        )
        return CompanionPresentationDirective(
            targetMode: .fullscreen,
            directUserOwnsReturn: true
        )
    }

    mutating func finish(
        continuesIntoFallback: Bool = false
    ) -> CompanionPresentationMode? {
        lifecycle.finish(continuesIntoFallback: continuesIntoFallback)
    }

    mutating func reset() {
        lifecycle.reset()
    }
}
