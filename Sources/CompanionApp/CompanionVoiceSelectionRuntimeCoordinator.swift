import Foundation

enum CompanionInteractionVoiceSelection: Equatable {
    case cooldown
    case unavailable
    case line(VoiceLine)
}

/// Owns only bounded, session-local voice-line selection state.
///
/// Audio playback, speaking state, UI copy, bundle loading and missing-file
/// presentation stay in the App composition layer. This coordinator receives
/// an already-loaded library and keeps general and gesture feedback histories
/// separate so one kind of response cannot exhaust the other.
final class CompanionVoiceSelectionRuntimeCoordinator {
    private let library: VoiceLineLibrary
    private var recentGeneralIDs: [String] = []
    private var recentInteractionIDs: [String] = []
    private var lastInteractionCueAt = Date.distantPast

    init(library: VoiceLineLibrary) {
        self.library = library
    }

    var audioFileNames: [String] {
        library.lines.map(\.audioFile)
    }

    func selectEvent(
        _ event: CompanionEventKind,
        addressedEnabled: Bool,
        preferredID: String? = nil
    ) -> VoiceLine? {
        let candidates = library.candidates(
            for: event,
            addressedEnabled: addressedEnabled,
            excluding: Set(recentGeneralIDs)
        )
        let selected: VoiceLine?
        if let preferredID {
            selected = candidates.first { $0.id == preferredID }
                ?? library.lines.first {
                    $0.id == preferredID
                        && (addressedEnabled || !$0.addressed)
                }
        } else {
            selected = candidates.randomElement()
        }
        rememberGeneral(selected)
        return selected
    }

    func selectAction(
        _ action: CompanionAction,
        addressedEnabled: Bool
    ) -> VoiceLine? {
        let selected = library.candidates(
            for: action,
            addressedEnabled: addressedEnabled,
            excluding: Set(recentGeneralIDs)
        ).randomElement()
        rememberGeneral(selected)
        return selected
    }

    func selectInteraction(
        _ event: CompanionEventKind,
        addressedEnabled: Bool,
        at now: Date,
        bypassCooldown: Bool
    ) -> CompanionInteractionVoiceSelection {
        if !bypassCooldown,
           now.timeIntervalSince(lastInteractionCueAt) < 0.32 {
            return .cooldown
        }
        guard let selected = library.candidates(
            for: event,
            addressedEnabled: addressedEnabled,
            excluding: Set(recentInteractionIDs)
        ).randomElement() else {
            return .unavailable
        }
        recentInteractionIDs.append(selected.id)
        recentInteractionIDs = Array(recentInteractionIDs.suffix(8))
        lastInteractionCueAt = now
        return .line(selected)
    }

    private func rememberGeneral(_ line: VoiceLine?) {
        guard let line else { return }
        recentGeneralIDs.append(line.id)
        recentGeneralIDs = Array(recentGeneralIDs.suffix(10))
    }
}
