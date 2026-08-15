import CompanionContracts
import Foundation

enum CompanionDefaultsKeys {
    static let playbackMode = "chengyin.playback.mode"
    static let playbackSelectionContractVersion =
        "chengyin.playback.selection-contract.version"
    static let reducedDynamicEffectsEnabled = "chengyin.performance.reduced-dynamic-effects"
    static let displayMode = "chengyin.window.display-mode"
    static let presentationAppearance = "chengyin.window.appearance"
    static let displayTargetMode = "chengyin.window.display-target.mode"
    static let displayTargetIdentifier = "chengyin.window.display-target.identifier"
    static let remindersEnabled = "chengyin.reminders.enabled"
    static let careCadence = "chengyin.reminders.cadence"
    static let timeAnnouncementsEnabled = "chengyin.reminders.time-announcements"
    static let halfHourlyAnnouncementsEnabled = "chengyin.reminders.half-hour"
    static let quietHoursEnabled = "chengyin.reminders.quiet-hours"
    static let flirtyRemindersEnabled = "chengyin.reminders.flirty"
    static let codexCompletionAnnouncementsEnabled = "chengyin.codex.completion-announcements"
    static let usePetName = "chengyin.voice.use-pet-name"
    static let randomOutfitsEnabled = "chengyin.character.random-outfits"
    static let petInteractionsEnabled = "chengyin.pet.click-interactions"
    static let localContentPacksEnabled = "chengyin.content-packs.enabled"
    static let recentPetMomentKeys = "chengyin.pet.recent-moments"
    static let learnedPetGestures = "chengyin.pet.learned-gestures.v1"
    static let catchGameBestScore = "chengyin.pet.catch-game.best-score"
    static let hideGameBestScore = "chengyin.pet.hide-game.best-score"
    static let firstSessionContractVersion =
        "chengyin.first-session.contract.version"
    static let firstSessionPreference = "chengyin.first-session.preference"
}

enum CompanionFirstSessionPreferences {
    static func launchDisposition(
        from defaults: UserDefaults
    ) -> CompanionFirstSessionLaunchDisposition {
        let storedVersion = defaults.integer(
            forKey: CompanionDefaultsKeys.firstSessionContractVersion
        )
        let existingProfileKeys = [
            CompanionDefaultsKeys.playbackMode,
            CompanionDefaultsKeys.playbackSelectionContractVersion,
            CompanionDefaultsKeys.displayMode,
            CompanionDefaultsKeys.remindersEnabled,
            CompanionDefaultsKeys.careCadence,
            CompanionDefaultsKeys.learnedPetGestures
        ]
        let hasExistingProfile = existingProfileKeys.contains(where: {
            defaults.object(forKey: $0) != nil
        })
        return CompanionFirstSessionLaunchPolicy.disposition(
            storedVersion: storedVersion,
            hasExistingProfile: hasExistingProfile
        )
    }

    static func markStarted(in defaults: UserDefaults) {
        defaults.set(
            -CompanionFirstSessionJourney.contractVersion,
            forKey: CompanionDefaultsKeys.firstSessionContractVersion
        )
    }

    static func markCompleted(
        preference: CompanionFirstSessionPreference?,
        in defaults: UserDefaults
    ) {
        defaults.set(
            CompanionFirstSessionJourney.contractVersion,
            forKey: CompanionDefaultsKeys.firstSessionContractVersion
        )
        if let preference {
            defaults.set(
                preference.rawValue,
                forKey: CompanionDefaultsKeys.firstSessionPreference
            )
        }
    }
}

enum CompanionPresentationPreferences {
    static func loadAppearance(from defaults: UserDefaults) -> CompanionPresentationAppearance {
        CompanionPresentationAppearance(
            rawValue: defaults.string(
                forKey: CompanionDefaultsKeys.presentationAppearance
            ) ?? ""
        ) ?? .transparent
    }

    static func loadDisplayTarget(from defaults: UserDefaults) -> CompanionDisplayTarget {
        let mode = CompanionDisplayTargetMode(
            rawValue: defaults.string(
                forKey: CompanionDefaultsKeys.displayTargetMode
            ) ?? ""
        ) ?? .followWindow
        let target = CompanionDisplayTarget(
            mode: mode,
            identifier: defaults.string(
                forKey: CompanionDefaultsKeys.displayTargetIdentifier
            )
        )
        return target.isValid ? target : .followWindow
    }

    static func save(
        appearance: CompanionPresentationAppearance,
        to defaults: UserDefaults
    ) {
        defaults.set(
            appearance.rawValue,
            forKey: CompanionDefaultsKeys.presentationAppearance
        )
    }

    static func save(target: CompanionDisplayTarget, to defaults: UserDefaults) {
        let safeTarget = target.isValid ? target : .followWindow
        defaults.set(
            safeTarget.mode.rawValue,
            forKey: CompanionDefaultsKeys.displayTargetMode
        )
        if let identifier = safeTarget.identifier {
            defaults.set(
                identifier,
                forKey: CompanionDefaultsKeys.displayTargetIdentifier
            )
        } else {
            defaults.removeObject(
                forKey: CompanionDefaultsKeys.displayTargetIdentifier
            )
        }
    }
}
