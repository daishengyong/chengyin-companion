import Foundation

enum CompanionPresentationMode: Equatable {
    case pet
    case stage
    case fullscreen
}

enum CompanionPresentationAppearance: Equatable {
    case transparent
    case cinematic
    case dim
}

enum CompanionDisplayTargetMode: Equatable {
    case followWindow
    case main
    case specific
}

struct CompanionDisplayTarget: Equatable {
    let mode: CompanionDisplayTargetMode
    let identifier: String?

    static let followWindow = CompanionDisplayTarget(
        mode: .followWindow,
        identifier: nil
    )
    static let main = CompanionDisplayTarget(mode: .main, identifier: nil)

    static func specific(_ identifier: String) -> CompanionDisplayTarget {
        CompanionDisplayTarget(mode: .specific, identifier: identifier)
    }

    var isValid: Bool {
        switch mode {
        case .followWindow, .main:
            return identifier == nil
        case .specific:
            guard let identifier else { return false }
            return !identifier.isEmpty
                && identifier == identifier.trimmingCharacters(in: .whitespacesAndNewlines)
                && !identifier.contains("/")
                && !identifier.contains("\\")
        }
    }
}

enum CompanionRelationshipTone: Equatable {
    case calmPeer
    case playfulSpark
    case warmSupport
    case romanceLite

    var allowsFlirtyReminders: Bool {
        self == .playfulSpark || self == .romanceLite
    }

    var allowsRomanticGestures: Bool {
        self == .romanceLite
    }
}

enum CompanionPlaybackPreference: Equatable {
    case audiovisual
    case audioOnly
}

enum CompanionCareCadencePreference: Equatable {
    case gentle
    case standard
    case lively
}

enum CompanionDisplayMode: Equatable {
    case full
    case compact
    case head
}

enum CompanionPlaybackMode: Equatable {
    case audioVisual
    case audioOnly
}

enum CompanionCareCadence: Equatable {
    case gentle
    case standard
    case lively
}

struct CompanionPreferenceSnapshot: Equatable {
    let playbackMode: CompanionPlaybackMode
    let reducedDynamicEffectsEnabled: Bool
    let displayMode: CompanionDisplayMode
    let presentationAppearance: CompanionPresentationAppearance
    let displayTarget: CompanionDisplayTarget
    let remindersEnabled: Bool
    let careCadence: CompanionCareCadence
    let timeAnnouncementsEnabled: Bool
    let halfHourlyAnnouncementsEnabled: Bool
    let quietHoursEnabled: Bool
    let flirtyRemindersEnabled: Bool
    let codexCompletionAnnouncementsEnabled: Bool
    let usePetName: Bool
    let randomOutfitsEnabled: Bool
    let petInteractionsEnabled: Bool
    let localContentPacksEnabled: Bool
    let catchGameBestScore: Int
    let hideGameBestScore: Int
}

struct CompanionSettingsV1: Equatable {
    var personaId: String
    var relationshipTone: CompanionRelationshipTone
    var locale: String
    var presentationMode: CompanionPresentationMode
    var presentationAppearance: CompanionPresentationAppearance
    var displayTarget: CompanionDisplayTarget
    var soundEnabled: Bool
    var interactionEnabled: Bool
    var sharingPromptEnabled: Bool
    var playbackPreference: CompanionPlaybackPreference
    var reducedDynamicEffectsEnabled: Bool
    var remindersEnabled: Bool
    var careCadence: CompanionCareCadencePreference
    var timeAnnouncementsEnabled: Bool
    var halfHourlyAnnouncementsEnabled: Bool
    var quietHoursEnabled: Bool
    var flirtyRemindersEnabled: Bool
    var codexCompletionAnnouncementsEnabled: Bool
    var usePetName: Bool
    var randomOutfitsEnabled: Bool
    var localContentPacksEnabled: Bool
    var learnedGestureIDs: [String]

    init(
        personaId: String = "starter.c01",
        relationshipTone: CompanionRelationshipTone = .warmSupport,
        locale: String = "en",
        presentationMode: CompanionPresentationMode = .pet,
        presentationAppearance: CompanionPresentationAppearance = .transparent,
        displayTarget: CompanionDisplayTarget = .followWindow,
        soundEnabled: Bool = true,
        interactionEnabled: Bool = true,
        sharingPromptEnabled: Bool = false,
        playbackPreference: CompanionPlaybackPreference = .audiovisual,
        reducedDynamicEffectsEnabled: Bool = false,
        remindersEnabled: Bool = true,
        careCadence: CompanionCareCadencePreference = .standard,
        timeAnnouncementsEnabled: Bool = true,
        halfHourlyAnnouncementsEnabled: Bool = false,
        quietHoursEnabled: Bool = true,
        flirtyRemindersEnabled: Bool = false,
        codexCompletionAnnouncementsEnabled: Bool = true,
        usePetName: Bool = false,
        randomOutfitsEnabled: Bool = true,
        localContentPacksEnabled: Bool = true,
        learnedGestureIDs: [String] = []
    ) {
        self.personaId = personaId
        self.relationshipTone = relationshipTone
        self.locale = locale
        self.presentationMode = presentationMode
        self.presentationAppearance = presentationAppearance
        self.displayTarget = displayTarget
        self.soundEnabled = soundEnabled
        self.interactionEnabled = interactionEnabled
        self.sharingPromptEnabled = sharingPromptEnabled
        self.playbackPreference = playbackPreference
        self.reducedDynamicEffectsEnabled = reducedDynamicEffectsEnabled
        self.remindersEnabled = remindersEnabled
        self.careCadence = careCadence
        self.timeAnnouncementsEnabled = timeAnnouncementsEnabled
        self.halfHourlyAnnouncementsEnabled = halfHourlyAnnouncementsEnabled
        self.quietHoursEnabled = quietHoursEnabled
        self.flirtyRemindersEnabled = flirtyRemindersEnabled
        self.codexCompletionAnnouncementsEnabled = codexCompletionAnnouncementsEnabled
        self.usePetName = usePetName
        self.randomOutfitsEnabled = randomOutfitsEnabled
        self.localContentPacksEnabled = localContentPacksEnabled
        self.learnedGestureIDs = learnedGestureIDs
    }
}

@main
enum CompanionSettingsBackupProjectionSmoke {
    static func main() throws {
        let preferences = CompanionPreferenceSnapshot(
            playbackMode: .audioOnly,
            reducedDynamicEffectsEnabled: false,
            displayMode: .full,
            presentationAppearance: .dim,
            displayTarget: .main,
            remindersEnabled: false,
            careCadence: .lively,
            timeAnnouncementsEnabled: false,
            halfHourlyAnnouncementsEnabled: true,
            quietHoursEnabled: false,
            flirtyRemindersEnabled: true,
            codexCompletionAnnouncementsEnabled: false,
            usePetName: true,
            randomOutfitsEnabled: false,
            petInteractionsEnabled: false,
            localContentPacksEnabled: false,
            catchGameBestScore: 5,
            hideGameBestScore: 4
        )
        let exported = CompanionSettingsBackupProjection.export(
            preferences: preferences,
            relationshipTone: .romanceLite,
            locale: "zh-Hans",
            learnedGestureIDs: ["single-tap", "drag-release"]
        )
        try require(exported.personaId == "starter.c01", "export changed the supported persona")
        try require(exported.soundEnabled, "export invented an unsupported mute state")
        try require(!exported.sharingPromptEnabled, "export enabled a retired sharing prompt")
        try require(exported.presentationMode == .fullscreen, "display mode did not map to fullscreen")
        try require(exported.playbackPreference == .audioOnly, "playback preference changed")
        try require(exported.careCadence == .lively, "care cadence changed")
        try require(exported.locale == "zh-Hans", "locale metadata changed")
        try require(exported.learnedGestureIDs == ["single-tap", "drag-release"], "gesture IDs changed")
        try require(!exported.interactionEnabled && !exported.remindersEnabled, "boolean preferences changed")

        let cleanPlan = CompanionSettingsBackupProjection.restore(
            exported,
            currentLocale: "zh-Hans"
        )
        try require(cleanPlan.repairs.isEmpty, "clean round-trip reported a repair")
        try require(cleanPlan.relationshipTone == .romanceLite, "relationship tone changed")
        try require(cleanPlan.displayMode == .full, "fullscreen did not round-trip")
        try require(cleanPlan.presentationAppearance == .dim, "appearance changed")
        try require(cleanPlan.displayTarget == .main, "display target changed")
        try require(cleanPlan.playbackMode == .audioOnly, "audio-only mode changed")
        try require(!cleanPlan.petInteractionsEnabled, "interaction preference changed")
        try require(cleanPlan.flirtyRemindersEnabled && cleanPlan.usePetName, "allowed romance preferences were removed")
        try require(cleanPlan.learnedGestureIDs == exported.learnedGestureIDs, "gesture IDs did not pass through")

        var incompatible = exported
        incompatible.personaId = "third-party.persona"
        incompatible.locale = "ja"
        incompatible.soundEnabled = false
        incompatible.sharingPromptEnabled = true
        incompatible.displayTarget = .specific("bad/path")
        incompatible.playbackPreference = .audiovisual
        incompatible.reducedDynamicEffectsEnabled = true
        incompatible.relationshipTone = .warmSupport
        incompatible.flirtyRemindersEnabled = true
        incompatible.usePetName = true
        incompatible.learnedGestureIDs = ["future-gesture", "single-tap"]
        let sourceBeforeRestore = incompatible
        let repaired = CompanionSettingsBackupProjection.restore(
            incompatible,
            currentLocale: "en"
        )
        try require(incompatible == sourceBeforeRestore, "restore mutated its source settings")
        try require(repaired.displayTarget == .followWindow, "invalid target did not fail safe")
        try require(repaired.playbackMode == .audioOnly, "low-dynamic restore did not force audio-only")
        try require(!repaired.flirtyRemindersEnabled, "tone-disallowed flirt survived restore")
        try require(!repaired.usePetName, "tone-disallowed pet name survived restore")
        try require(
            repaired.learnedGestureIDs == ["future-gesture", "single-tap"],
            "projection silently canonicalized gesture capabilities"
        )
        try require(
            repaired.repairs == [
                .unsupportedPersona,
                .localeFollowsCurrentApp,
                .soundToggleUnsupported,
                .sharingPromptDiscarded,
                .invalidDisplayTarget,
                .reducedDynamicsForcedAudioOnly,
                .flirtyReminderDisallowedByTone,
                .petNameDisallowedByTone,
            ],
            "repair receipt lost stable order or an explicit adjustment"
        )

        var playful = exported
        playful.relationshipTone = .playfulSpark
        playful.flirtyRemindersEnabled = true
        playful.usePetName = true
        let playfulPlan = CompanionSettingsBackupProjection.restore(
            playful,
            currentLocale: "zh-Hans"
        )
        try require(playfulPlan.flirtyRemindersEnabled, "playful flirt was incorrectly removed")
        try require(!playfulPlan.usePetName, "playful tone bypassed the romance-only pet-name gate")
        try require(playfulPlan.repairs == [.petNameDisallowedByTone], "playful repair receipt changed")

        var alreadyLowImpact = exported
        alreadyLowImpact.reducedDynamicEffectsEnabled = true
        alreadyLowImpact.playbackPreference = .audioOnly
        let lowImpactPlan = CompanionSettingsBackupProjection.restore(
            alreadyLowImpact,
            currentLocale: "zh-Hans"
        )
        try require(
            !lowImpactPlan.repairs.contains(.reducedDynamicsForcedAudioOnly),
            "already-compatible low-impact settings reported a false repair"
        )

        print(
            "Companion settings backup projection smoke: PASS "
                + "(export, round-trip, fallback, privacy retirement, tone gates, low-impact, receipt order, no mutation)"
        )
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else { throw Failure(message) }
    }
}

private struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
