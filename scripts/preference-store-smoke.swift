import CompanionContracts
import Foundation

enum CompanionPlaybackMode: String {
    case audioVisual
    case audioOnly
}

enum CompanionDisplayMode: String {
    case full
    case compact
    case head
}

enum CompanionCareCadence: String {
    case gentle
    case standard
    case lively
}

@main
enum CompanionPreferenceStoreSmoke {
    static func main() throws {
        let suiteName = "local.chengyin.preference-smoke.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw Failure("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.removePersistentDomain(forName: suiteName)
        let store = CompanionPreferenceStore(defaults: defaults)

        let clean = store.load()
        try require(clean.snapshot.playbackMode == .audioVisual, "Clean playback default changed")
        try require(clean.snapshot.displayMode == .head, "Clean display default changed")
        try require(clean.snapshot.presentationAppearance == .transparent, "Clean appearance changed")
        try require(clean.snapshot.displayTarget == .followWindow, "Clean display target changed")
        try require(clean.snapshot.remindersEnabled, "Clean reminders default changed")
        try require(clean.snapshot.careCadence == .standard, "Clean cadence default changed")
        try require(clean.snapshot.timeAnnouncementsEnabled, "Clean time announcement default changed")
        try require(!clean.snapshot.halfHourlyAnnouncementsEnabled, "Clean half-hour default changed")
        try require(clean.snapshot.quietHoursEnabled, "Clean quiet-hours default changed")
        try require(!clean.snapshot.flirtyRemindersEnabled, "Clean flirt default changed")
        try require(clean.snapshot.codexCompletionAnnouncementsEnabled, "Clean completion default changed")
        try require(!clean.snapshot.usePetName, "Clean pet-name default changed")
        try require(clean.snapshot.randomOutfitsEnabled, "Clean outfit default changed")
        try require(clean.snapshot.petInteractionsEnabled, "Clean interaction default changed")
        try require(clean.snapshot.localContentPacksEnabled, "Clean content-pack default changed")
        try require(clean.upgradedPlaybackSelectionContract, "Clean install did not establish playback contract")
        try require(clean.repairedFieldCount == 0, "Clean install reported corrupt fields")

        defaults.set(
            CompanionPlaybackMode.audioOnly.rawValue,
            forKey: CompanionDefaultsKeys.playbackMode
        )
        defaults.set(1, forKey: CompanionDefaultsKeys.playbackSelectionContractVersion)
        defaults.set(false, forKey: CompanionDefaultsKeys.reducedDynamicEffectsEnabled)
        let migrated = store.load()
        try require(migrated.snapshot.playbackMode == .audioVisual, "Legacy accidental audio-only was not migrated")
        try require(migrated.upgradedPlaybackSelectionContract, "Legacy migration receipt was missing")
        try require(
            defaults.string(forKey: CompanionDefaultsKeys.playbackMode)
                == CompanionPlaybackMode.audioVisual.rawValue,
            "Legacy migration was not persisted"
        )

        defaults.set(
            CompanionPlaybackMode.audioVisual.rawValue,
            forKey: CompanionDefaultsKeys.playbackMode
        )
        defaults.set(1, forKey: CompanionDefaultsKeys.playbackSelectionContractVersion)
        defaults.set(true, forKey: CompanionDefaultsKeys.reducedDynamicEffectsEnabled)
        let lowImpact = store.load()
        try require(lowImpact.snapshot.playbackMode == .audioOnly, "Low-impact mode did not force audio-only")
        try require(lowImpact.snapshot.reducedDynamicEffectsEnabled, "Low-impact mode was lost")

        defaults.set(9, forKey: CompanionDefaultsKeys.playbackSelectionContractVersion)
        let futureContract = store.load()
        try require(!futureContract.upgradedPlaybackSelectionContract, "Future contract was treated as legacy")
        try require(
            defaults.integer(forKey: CompanionDefaultsKeys.playbackSelectionContractVersion) == 9,
            "Future contract was silently downgraded"
        )

        defaults.set("broken", forKey: CompanionDefaultsKeys.playbackMode)
        defaults.set("broken", forKey: CompanionDefaultsKeys.remindersEnabled)
        defaults.set("specific", forKey: CompanionDefaultsKeys.displayTargetMode)
        defaults.set("/private/secret", forKey: CompanionDefaultsKeys.displayTargetIdentifier)
        defaults.set(99, forKey: CompanionDefaultsKeys.catchGameBestScore)
        defaults.set(-4, forKey: CompanionDefaultsKeys.hideGameBestScore)
        defaults.set("private prompt", forKey: "chengyin.ui.messages")
        defaults.set("thread-secret", forKey: "chengyin.codex.thread-id")
        defaults.set(false, forKey: CompanionDefaultsKeys.reducedDynamicEffectsEnabled)
        let repaired = store.load()
        try require(repaired.snapshot.playbackMode == .audioVisual, "Corrupt playback did not fall back")
        try require(repaired.snapshot.remindersEnabled, "Corrupt boolean did not use safe default")
        try require(repaired.snapshot.displayTarget == .followWindow, "Unsafe display target was retained")
        try require(repaired.snapshot.catchGameBestScore == 5, "High score was not bounded")
        try require(repaired.snapshot.hideGameBestScore == 0, "Negative score was not bounded")
        try require(repaired.repairedFieldCount >= 5, "Repair receipt under-counted malformed fields")
        try require(repaired.removedDeprecatedKeyCount == 2, "Privacy cleanup receipt was incorrect")
        try require(defaults.object(forKey: "chengyin.ui.messages") == nil, "Retired message content survived")
        try require(defaults.object(forKey: "chengyin.codex.thread-id") == nil, "Retired thread ID survived")
        let repairedReload = store.load()
        try require(repairedReload.repairedFieldCount == 0, "Repairs were not stable across restart")
        try require(repairedReload.removedDeprecatedKeyCount == 0, "Privacy cleanup repeated after restart")

        store.savePlaybackMode(.audioOnly)
        store.markPlaybackSelectionCurrent()
        store.saveReducedDynamicEffectsEnabled(false)
        store.saveDisplayMode(.compact)
        store.savePresentationAppearance(.cinematic)
        store.saveDisplayTarget(.specific("display-2"))
        store.saveRemindersEnabled(false)
        store.saveCareCadence(.lively)
        store.saveTimeAnnouncementsEnabled(false)
        store.saveHalfHourlyAnnouncementsEnabled(true)
        store.saveQuietHoursEnabled(false)
        store.saveFlirtyRemindersEnabled(true)
        store.saveCompletionAnnouncementsEnabled(false)
        store.saveUsePetName(true)
        store.saveRandomOutfitsEnabled(false)
        store.savePetInteractionsEnabled(false)
        store.saveLocalContentPacksEnabled(false)
        store.saveCatchGameBestScore(8)
        store.saveHideGameBestScore(-2)
        let roundTrip = store.load().snapshot
        try require(roundTrip.playbackMode == .audioOnly, "Playback write did not round-trip")
        try require(roundTrip.displayMode == .compact, "Display write did not round-trip")
        try require(roundTrip.presentationAppearance == .cinematic, "Appearance write did not round-trip")
        try require(roundTrip.displayTarget == .specific("display-2"), "Display target did not round-trip")
        try require(!roundTrip.remindersEnabled && roundTrip.careCadence == .lively, "Care writes did not round-trip")
        try require(!roundTrip.timeAnnouncementsEnabled && roundTrip.halfHourlyAnnouncementsEnabled, "Time writes did not round-trip")
        try require(!roundTrip.quietHoursEnabled && roundTrip.flirtyRemindersEnabled, "Tone writes did not round-trip")
        try require(!roundTrip.codexCompletionAnnouncementsEnabled, "Completion write did not round-trip")
        try require(roundTrip.usePetName && !roundTrip.randomOutfitsEnabled, "Character writes did not round-trip")
        try require(!roundTrip.petInteractionsEnabled && !roundTrip.localContentPacksEnabled, "Interaction writes did not round-trip")
        try require(roundTrip.catchGameBestScore == 5 && roundTrip.hideGameBestScore == 0, "Score writes were not bounded")

        print(
            "Companion preference store smoke: PASS "
                + "(defaults, migration, forward contract, corrupt repair, privacy cleanup, restart, round-trip)"
        )
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else { throw Failure(message) }
    }
}

private struct Failure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
