#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif

enum CompanionSettingsRestoreRepair: String, Equatable, CaseIterable {
    case unsupportedPersona
    case localeFollowsCurrentApp
    case soundToggleUnsupported
    case sharingPromptDiscarded
    case invalidDisplayTarget
    case reducedDynamicsForcedAudioOnly
    case flirtyReminderDisallowedByTone
    case petNameDisallowedByTone
}

struct CompanionSettingsRestorePlan: Equatable {
    let relationshipTone: CompanionRelationshipTone
    let displayMode: CompanionDisplayMode
    let presentationAppearance: CompanionPresentationAppearance
    let displayTarget: CompanionDisplayTarget
    let playbackMode: CompanionPlaybackMode
    let reducedDynamicEffectsEnabled: Bool
    let petInteractionsEnabled: Bool
    let remindersEnabled: Bool
    let careCadence: CompanionCareCadence
    let timeAnnouncementsEnabled: Bool
    let halfHourlyAnnouncementsEnabled: Bool
    let quietHoursEnabled: Bool
    let flirtyRemindersEnabled: Bool
    let codexCompletionAnnouncementsEnabled: Bool
    let usePetName: Bool
    let randomOutfitsEnabled: Bool
    let localContentPacksEnabled: Bool
    let learnedGestureIDs: [String]
    let repairs: [CompanionSettingsRestoreRepair]
}

/// Pure, capability-free projection between local preferences and the portable
/// backup contract. Unsupported or privacy-retired fields are never silently
/// applied: restore returns a stable ordered repair receipt for App presentation.
enum CompanionSettingsBackupProjection {
    static let supportedPersonaID = "starter.c01"

    static func export(
        preferences: CompanionPreferenceSnapshot,
        relationshipTone: CompanionRelationshipTone,
        locale: String,
        learnedGestureIDs: [String]
    ) -> CompanionSettingsV1 {
        CompanionSettingsV1(
            personaId: supportedPersonaID,
            relationshipTone: relationshipTone,
            locale: locale,
            presentationMode: presentationMode(preferences.displayMode),
            presentationAppearance: preferences.presentationAppearance,
            displayTarget: preferences.displayTarget,
            soundEnabled: true,
            interactionEnabled: preferences.petInteractionsEnabled,
            sharingPromptEnabled: false,
            playbackPreference: playbackPreference(preferences.playbackMode),
            reducedDynamicEffectsEnabled: preferences.reducedDynamicEffectsEnabled,
            remindersEnabled: preferences.remindersEnabled,
            careCadence: careCadencePreference(preferences.careCadence),
            timeAnnouncementsEnabled: preferences.timeAnnouncementsEnabled,
            halfHourlyAnnouncementsEnabled: preferences.halfHourlyAnnouncementsEnabled,
            quietHoursEnabled: preferences.quietHoursEnabled,
            flirtyRemindersEnabled: preferences.flirtyRemindersEnabled,
            codexCompletionAnnouncementsEnabled: preferences.codexCompletionAnnouncementsEnabled,
            usePetName: preferences.usePetName,
            randomOutfitsEnabled: preferences.randomOutfitsEnabled,
            localContentPacksEnabled: preferences.localContentPacksEnabled,
            learnedGestureIDs: learnedGestureIDs
        )
    }

    static func restore(
        _ settings: CompanionSettingsV1,
        currentLocale: String
    ) -> CompanionSettingsRestorePlan {
        var repairs: [CompanionSettingsRestoreRepair] = []
        if settings.personaId != supportedPersonaID {
            repairs.append(.unsupportedPersona)
        }
        if settings.locale != currentLocale {
            repairs.append(.localeFollowsCurrentApp)
        }
        if !settings.soundEnabled {
            repairs.append(.soundToggleUnsupported)
        }
        if settings.sharingPromptEnabled {
            repairs.append(.sharingPromptDiscarded)
        }

        let displayTarget: CompanionDisplayTarget
        if settings.displayTarget.isValid {
            displayTarget = settings.displayTarget
        } else {
            displayTarget = .followWindow
            repairs.append(.invalidDisplayTarget)
        }

        let playbackMode: CompanionPlaybackMode
        if settings.reducedDynamicEffectsEnabled {
            playbackMode = .audioOnly
            if settings.playbackPreference != .audioOnly {
                repairs.append(.reducedDynamicsForcedAudioOnly)
            }
        } else {
            playbackMode = restoredPlaybackMode(settings.playbackPreference)
        }

        let flirtyRemindersEnabled = settings.flirtyRemindersEnabled
            && settings.relationshipTone.allowsFlirtyReminders
        if settings.flirtyRemindersEnabled && !flirtyRemindersEnabled {
            repairs.append(.flirtyReminderDisallowedByTone)
        }
        let usePetName = settings.usePetName
            && settings.relationshipTone.allowsRomanticGestures
        if settings.usePetName && !usePetName {
            repairs.append(.petNameDisallowedByTone)
        }

        return CompanionSettingsRestorePlan(
            relationshipTone: settings.relationshipTone,
            displayMode: displayMode(settings.presentationMode),
            presentationAppearance: settings.presentationAppearance,
            displayTarget: displayTarget,
            playbackMode: playbackMode,
            reducedDynamicEffectsEnabled: settings.reducedDynamicEffectsEnabled,
            petInteractionsEnabled: settings.interactionEnabled,
            remindersEnabled: settings.remindersEnabled,
            careCadence: careCadence(settings.careCadence),
            timeAnnouncementsEnabled: settings.timeAnnouncementsEnabled,
            halfHourlyAnnouncementsEnabled: settings.halfHourlyAnnouncementsEnabled,
            quietHoursEnabled: settings.quietHoursEnabled,
            flirtyRemindersEnabled: flirtyRemindersEnabled,
            codexCompletionAnnouncementsEnabled: settings.codexCompletionAnnouncementsEnabled,
            usePetName: usePetName,
            randomOutfitsEnabled: settings.randomOutfitsEnabled,
            localContentPacksEnabled: settings.localContentPacksEnabled,
            learnedGestureIDs: settings.learnedGestureIDs,
            repairs: repairs
        )
    }

    private static func presentationMode(
        _ displayMode: CompanionDisplayMode
    ) -> CompanionPresentationMode {
        switch displayMode {
        case .head: .pet
        case .compact: .stage
        case .full: .fullscreen
        }
    }

    private static func displayMode(
        _ presentationMode: CompanionPresentationMode
    ) -> CompanionDisplayMode {
        switch presentationMode {
        case .pet: .head
        case .stage: .compact
        case .fullscreen: .full
        }
    }

    private static func playbackPreference(
        _ playbackMode: CompanionPlaybackMode
    ) -> CompanionPlaybackPreference {
        switch playbackMode {
        case .audioVisual: .audiovisual
        case .audioOnly: .audioOnly
        }
    }

    private static func restoredPlaybackMode(
        _ preference: CompanionPlaybackPreference
    ) -> CompanionPlaybackMode {
        switch preference {
        case .audiovisual: .audioVisual
        case .audioOnly: .audioOnly
        }
    }

    private static func careCadencePreference(
        _ cadence: CompanionCareCadence
    ) -> CompanionCareCadencePreference {
        switch cadence {
        case .gentle: .gentle
        case .standard: .standard
        case .lively: .lively
        }
    }

    private static func careCadence(
        _ preference: CompanionCareCadencePreference
    ) -> CompanionCareCadence {
        switch preference {
        case .gentle: .gentle
        case .standard: .standard
        case .lively: .lively
        }
    }
}
