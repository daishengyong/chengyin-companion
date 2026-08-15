import CompanionContracts
import Foundation

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

struct CompanionPreferenceLoadReceipt: Equatable {
    let snapshot: CompanionPreferenceSnapshot
    let upgradedPlaybackSelectionContract: Bool
    let repairedFieldCount: Int
    let removedDeprecatedKeyCount: Int
}

/// Owns the local, privacy-minimal preference schema and its one-way repairs.
///
/// The view model observes values and performs UI side effects; this boundary
/// alone maps those values to UserDefaults keys, repairs malformed stored
/// values and removes the retired conversation keys. It owns no account,
/// network, media, window, task-content or filesystem capability.
final class CompanionPreferenceStore {
    private static let playbackSelectionContractVersion = 2
    private static let deprecatedConversationKeys = [
        "chengyin.ui.messages",
        "chengyin.voice.auto-speak",
        "chengyin.voice.auto-send",
        "chengyin.voice.language",
        "chengyin.codex.thread-id"
    ]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> CompanionPreferenceLoadReceipt {
        var repairedFieldCount = 0
        let reducedDynamicEffectsEnabled = bool(
            forKey: CompanionDefaultsKeys.reducedDynamicEffectsEnabled,
            fallback: false,
            repairedFieldCount: &repairedFieldCount
        )
        let storedPlaybackMode: CompanionPlaybackMode = rawValue(
            forKey: CompanionDefaultsKeys.playbackMode,
            fallback: .audioVisual,
            repairedFieldCount: &repairedFieldCount
        )
        let storedContractVersion = integer(
            forKey: CompanionDefaultsKeys.playbackSelectionContractVersion,
            fallback: 0,
            range: 0...Int.max,
            repairedFieldCount: &repairedFieldCount
        )
        let upgradedPlaybackSelectionContract =
            storedContractVersion < Self.playbackSelectionContractVersion
        let migratedPlaybackMode = upgradedPlaybackSelectionContract
            && !reducedDynamicEffectsEnabled
            ? CompanionPlaybackMode.audioVisual
            : storedPlaybackMode
        if upgradedPlaybackSelectionContract && !reducedDynamicEffectsEnabled {
            savePlaybackMode(migratedPlaybackMode)
        }
        if upgradedPlaybackSelectionContract {
            markPlaybackSelectionCurrent()
        }

        let displayMode: CompanionDisplayMode = rawValue(
            forKey: CompanionDefaultsKeys.displayMode,
            fallback: .head,
            repairedFieldCount: &repairedFieldCount
        )
        let appearance: CompanionPresentationAppearance = rawValue(
            forKey: CompanionDefaultsKeys.presentationAppearance,
            fallback: .transparent,
            repairedFieldCount: &repairedFieldCount
        )
        let displayTarget = loadDisplayTarget(
            repairedFieldCount: &repairedFieldCount
        )
        let remindersEnabled = bool(
            forKey: CompanionDefaultsKeys.remindersEnabled,
            fallback: true,
            repairedFieldCount: &repairedFieldCount
        )
        let careCadence: CompanionCareCadence = rawValue(
            forKey: CompanionDefaultsKeys.careCadence,
            fallback: .standard,
            repairedFieldCount: &repairedFieldCount
        )
        let timeAnnouncementsEnabled = bool(
            forKey: CompanionDefaultsKeys.timeAnnouncementsEnabled,
            fallback: true,
            repairedFieldCount: &repairedFieldCount
        )
        let halfHourlyAnnouncementsEnabled = bool(
            forKey: CompanionDefaultsKeys.halfHourlyAnnouncementsEnabled,
            fallback: false,
            repairedFieldCount: &repairedFieldCount
        )
        let quietHoursEnabled = bool(
            forKey: CompanionDefaultsKeys.quietHoursEnabled,
            fallback: true,
            repairedFieldCount: &repairedFieldCount
        )
        let flirtyRemindersEnabled = bool(
            forKey: CompanionDefaultsKeys.flirtyRemindersEnabled,
            fallback: false,
            repairedFieldCount: &repairedFieldCount
        )
        let completionAnnouncementsEnabled = bool(
            forKey: CompanionDefaultsKeys.codexCompletionAnnouncementsEnabled,
            fallback: true,
            repairedFieldCount: &repairedFieldCount
        )
        let usePetName = bool(
            forKey: CompanionDefaultsKeys.usePetName,
            fallback: false,
            repairedFieldCount: &repairedFieldCount
        )
        let randomOutfitsEnabled = bool(
            forKey: CompanionDefaultsKeys.randomOutfitsEnabled,
            fallback: true,
            repairedFieldCount: &repairedFieldCount
        )
        let petInteractionsEnabled = bool(
            forKey: CompanionDefaultsKeys.petInteractionsEnabled,
            fallback: true,
            repairedFieldCount: &repairedFieldCount
        )
        let localContentPacksEnabled = bool(
            forKey: CompanionDefaultsKeys.localContentPacksEnabled,
            fallback: true,
            repairedFieldCount: &repairedFieldCount
        )
        let catchGameBestScore = integer(
            forKey: CompanionDefaultsKeys.catchGameBestScore,
            fallback: 0,
            range: 0...5,
            repairedFieldCount: &repairedFieldCount
        )
        let hideGameBestScore = integer(
            forKey: CompanionDefaultsKeys.hideGameBestScore,
            fallback: 0,
            range: 0...5,
            repairedFieldCount: &repairedFieldCount
        )
        let removedDeprecatedKeyCount = removeDeprecatedConversationKeys()

        return CompanionPreferenceLoadReceipt(
            snapshot: CompanionPreferenceSnapshot(
                playbackMode: reducedDynamicEffectsEnabled
                    ? .audioOnly
                    : migratedPlaybackMode,
                reducedDynamicEffectsEnabled: reducedDynamicEffectsEnabled,
                displayMode: displayMode,
                presentationAppearance: appearance,
                displayTarget: displayTarget,
                remindersEnabled: remindersEnabled,
                careCadence: careCadence,
                timeAnnouncementsEnabled: timeAnnouncementsEnabled,
                halfHourlyAnnouncementsEnabled: halfHourlyAnnouncementsEnabled,
                quietHoursEnabled: quietHoursEnabled,
                flirtyRemindersEnabled: flirtyRemindersEnabled,
                codexCompletionAnnouncementsEnabled: completionAnnouncementsEnabled,
                usePetName: usePetName,
                randomOutfitsEnabled: randomOutfitsEnabled,
                petInteractionsEnabled: petInteractionsEnabled,
                localContentPacksEnabled: localContentPacksEnabled,
                catchGameBestScore: catchGameBestScore,
                hideGameBestScore: hideGameBestScore
            ),
            upgradedPlaybackSelectionContract: upgradedPlaybackSelectionContract,
            repairedFieldCount: repairedFieldCount,
            removedDeprecatedKeyCount: removedDeprecatedKeyCount
        )
    }

    func savePlaybackMode(_ value: CompanionPlaybackMode) {
        defaults.set(value.rawValue, forKey: CompanionDefaultsKeys.playbackMode)
    }

    func markPlaybackSelectionCurrent() {
        defaults.set(
            Self.playbackSelectionContractVersion,
            forKey: CompanionDefaultsKeys.playbackSelectionContractVersion
        )
    }

    func saveReducedDynamicEffectsEnabled(_ value: Bool) {
        defaults.set(
            value,
            forKey: CompanionDefaultsKeys.reducedDynamicEffectsEnabled
        )
    }

    func saveDisplayMode(_ value: CompanionDisplayMode) {
        defaults.set(value.rawValue, forKey: CompanionDefaultsKeys.displayMode)
    }

    func savePresentationAppearance(_ value: CompanionPresentationAppearance) {
        CompanionPresentationPreferences.save(appearance: value, to: defaults)
    }

    func saveDisplayTarget(_ value: CompanionDisplayTarget) {
        CompanionPresentationPreferences.save(target: value, to: defaults)
    }

    func saveRemindersEnabled(_ value: Bool) {
        defaults.set(value, forKey: CompanionDefaultsKeys.remindersEnabled)
    }

    func saveCareCadence(_ value: CompanionCareCadence) {
        defaults.set(value.rawValue, forKey: CompanionDefaultsKeys.careCadence)
    }

    func saveTimeAnnouncementsEnabled(_ value: Bool) {
        defaults.set(value, forKey: CompanionDefaultsKeys.timeAnnouncementsEnabled)
    }

    func saveHalfHourlyAnnouncementsEnabled(_ value: Bool) {
        defaults.set(value, forKey: CompanionDefaultsKeys.halfHourlyAnnouncementsEnabled)
    }

    func saveQuietHoursEnabled(_ value: Bool) {
        defaults.set(value, forKey: CompanionDefaultsKeys.quietHoursEnabled)
    }

    func saveFlirtyRemindersEnabled(_ value: Bool) {
        defaults.set(value, forKey: CompanionDefaultsKeys.flirtyRemindersEnabled)
    }

    func saveCompletionAnnouncementsEnabled(_ value: Bool) {
        defaults.set(
            value,
            forKey: CompanionDefaultsKeys.codexCompletionAnnouncementsEnabled
        )
    }

    func saveUsePetName(_ value: Bool) {
        defaults.set(value, forKey: CompanionDefaultsKeys.usePetName)
    }

    func saveRandomOutfitsEnabled(_ value: Bool) {
        defaults.set(value, forKey: CompanionDefaultsKeys.randomOutfitsEnabled)
    }

    func savePetInteractionsEnabled(_ value: Bool) {
        defaults.set(value, forKey: CompanionDefaultsKeys.petInteractionsEnabled)
    }

    func saveLocalContentPacksEnabled(_ value: Bool) {
        defaults.set(value, forKey: CompanionDefaultsKeys.localContentPacksEnabled)
    }

    func saveCatchGameBestScore(_ value: Int) {
        defaults.set(min(max(value, 0), 5), forKey: CompanionDefaultsKeys.catchGameBestScore)
    }

    func saveHideGameBestScore(_ value: Int) {
        defaults.set(min(max(value, 0), 5), forKey: CompanionDefaultsKeys.hideGameBestScore)
    }

    private func loadDisplayTarget(
        repairedFieldCount: inout Int
    ) -> CompanionDisplayTarget {
        let mode: CompanionDisplayTargetMode = rawValue(
            forKey: CompanionDefaultsKeys.displayTargetMode,
            fallback: .followWindow,
            repairedFieldCount: &repairedFieldCount
        )
        let identifier: String?
        if let stored = defaults.object(
            forKey: CompanionDefaultsKeys.displayTargetIdentifier
        ) {
            if let value = stored as? String {
                identifier = value
            } else {
                repairedFieldCount += 1
                defaults.removeObject(
                    forKey: CompanionDefaultsKeys.displayTargetIdentifier
                )
                identifier = nil
            }
        } else {
            identifier = nil
        }
        let target = CompanionDisplayTarget(mode: mode, identifier: identifier)
        guard target.isValid else {
            repairedFieldCount += 1
            CompanionPresentationPreferences.save(target: .followWindow, to: defaults)
            return .followWindow
        }
        return target
    }

    private func rawValue<Value: RawRepresentable>(
        forKey key: String,
        fallback: Value,
        repairedFieldCount: inout Int
    ) -> Value where Value.RawValue == String {
        guard let stored = defaults.object(forKey: key) else { return fallback }
        guard let rawValue = stored as? String,
              let value = Value(rawValue: rawValue) else {
            repairedFieldCount += 1
            defaults.removeObject(forKey: key)
            return fallback
        }
        return value
    }

    private func bool(
        forKey key: String,
        fallback: Bool,
        repairedFieldCount: inout Int
    ) -> Bool {
        guard let stored = defaults.object(forKey: key) else { return fallback }
        guard let value = stored as? Bool else {
            repairedFieldCount += 1
            defaults.removeObject(forKey: key)
            return fallback
        }
        return value
    }

    private func integer(
        forKey key: String,
        fallback: Int,
        range: ClosedRange<Int>,
        repairedFieldCount: inout Int
    ) -> Int {
        guard let stored = defaults.object(forKey: key) else { return fallback }
        guard let value = stored as? Int else {
            repairedFieldCount += 1
            defaults.removeObject(forKey: key)
            return fallback
        }
        let bounded = min(max(value, range.lowerBound), range.upperBound)
        if bounded != value {
            repairedFieldCount += 1
            defaults.set(bounded, forKey: key)
        }
        return bounded
    }

    private func removeDeprecatedConversationKeys() -> Int {
        var removed = 0
        for key in Self.deprecatedConversationKeys
        where defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
            removed += 1
        }
        return removed
    }
}
