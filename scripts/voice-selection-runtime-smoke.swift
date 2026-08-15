import Foundation

enum CompanionEventKind: String {
    case hydration
    case movement
    case flirt
    case lateNight
}

enum CompanionAction {
    case drink
    case stretch
}

struct VoiceLine: Equatable {
    let id: String
    let event: CompanionEventKind
    let action: CompanionAction
    let text: String
    let audioFile: String
    let addressed: Bool
}

struct VoiceLineLibrary {
    let lines: [VoiceLine]

    func candidates(
        for event: CompanionEventKind,
        addressedEnabled: Bool,
        excluding excludedIDs: Set<String>
    ) -> [VoiceLine] {
        let eventLines = lines.filter {
            $0.event == event && (addressedEnabled || !$0.addressed)
        }
        let fresh = eventLines.filter { !excludedIDs.contains($0.id) }
        return fresh.isEmpty ? eventLines : fresh
    }

    func candidates(
        for action: CompanionAction,
        addressedEnabled: Bool,
        excluding excludedIDs: Set<String>
    ) -> [VoiceLine] {
        let actionLines = lines.filter {
            $0.action == action && (addressedEnabled || !$0.addressed)
        }
        let fresh = actionLines.filter { !excludedIDs.contains($0.id) }
        return fresh.isEmpty ? actionLines : fresh
    }
}

@main
enum CompanionVoiceSelectionRuntimeSmoke {
    static func main() throws {
        let publicOne = line("public-1", event: .hydration, action: .drink)
        let publicTwo = line("public-2", event: .hydration, action: .drink)
        let addressed = line(
            "addressed-1",
            event: .hydration,
            action: .drink,
            addressed: true
        )
        let movementOne = line("move-1", event: .movement, action: .stretch)
        let movementTwo = line("move-2", event: .movement, action: .stretch)
        let library = VoiceLineLibrary(
            lines: [publicOne, publicTwo, addressed, movementOne, movementTwo]
        )
        let runtime = CompanionVoiceSelectionRuntimeCoordinator(library: library)

        try require(
            runtime.audioFileNames == library.lines.map(\.audioFile),
            "audio inventory changed order"
        )

        let first = try requireLine(
            runtime.selectEvent(.hydration, addressedEnabled: false),
            "first public event line was unavailable"
        )
        let second = try requireLine(
            runtime.selectEvent(.hydration, addressedEnabled: false),
            "second public event line was unavailable"
        )
        try require(first.id != second.id, "general history repeated before the public pool was exhausted")
        try require(!first.addressed && !second.addressed, "addressed line bypassed the opt-in gate")

        try require(
            runtime.selectEvent(
                .hydration,
                addressedEnabled: false,
                preferredID: addressed.id
            ) == nil,
            "preferred addressed line bypassed the opt-in gate"
        )
        let preferred = try requireLine(
            runtime.selectEvent(
                .hydration,
                addressedEnabled: true,
                preferredID: addressed.id
            ),
            "allowed preferred line was unavailable"
        )
        try require(preferred.id == addressed.id, "preferred line lost exact-ID priority")

        let actionRuntime = CompanionVoiceSelectionRuntimeCoordinator(library: library)
        let actionFirst = try requireLine(
            actionRuntime.selectAction(.stretch, addressedEnabled: false),
            "first action line was unavailable"
        )
        let actionSecond = try requireLine(
            actionRuntime.selectAction(.stretch, addressedEnabled: false),
            "second action line was unavailable"
        )
        try require(actionFirst.id != actionSecond.id, "action history repeated before exhaustion")

        let interactionRuntime = CompanionVoiceSelectionRuntimeCoordinator(library: library)
        let now = Date(timeIntervalSince1970: 1_000)
        let interactionFirst = interactionRuntime.selectInteraction(
            .movement,
            addressedEnabled: false,
            at: now,
            bypassCooldown: false
        )
        guard case let .line(firstInteractionLine) = interactionFirst else {
            throw Failure("first interaction line was unavailable")
        }
        try require(
            interactionRuntime.selectInteraction(
                .movement,
                addressedEnabled: false,
                at: now.addingTimeInterval(0.1),
                bypassCooldown: false
            ) == .cooldown,
            "interaction cooldown was not enforced"
        )
        let bypassed = interactionRuntime.selectInteraction(
            .movement,
            addressedEnabled: false,
            at: now.addingTimeInterval(0.1),
            bypassCooldown: true
        )
        guard case let .line(bypassedLine) = bypassed else {
            throw Failure("explicit cooldown bypass did not select a line")
        }
        try require(
            firstInteractionLine.id != bypassedLine.id,
            "interaction history repeated before exhaustion"
        )
        try require(
            interactionRuntime.selectInteraction(
                .lateNight,
                addressedEnabled: false,
                at: now.addingTimeInterval(1),
                bypassCooldown: false
            ) == .unavailable,
            "missing interaction event did not return unavailable"
        )

        let oneLineRuntime = CompanionVoiceSelectionRuntimeCoordinator(
            library: VoiceLineLibrary(lines: [publicOne])
        )
        _ = oneLineRuntime.selectEvent(.hydration, addressedEnabled: false)
        guard case .line = oneLineRuntime.selectInteraction(
            .hydration,
            addressedEnabled: false,
            at: now,
            bypassCooldown: false
        ) else {
            throw Failure("general history leaked into interaction history")
        }

        print(
            "Companion voice selection runtime smoke: PASS "
                + "(inventory, filtering, rotation, preferred ID, action, cooldown, missing, isolation)"
        )
    }

    private static func line(
        _ id: String,
        event: CompanionEventKind,
        action: CompanionAction,
        addressed: Bool = false
    ) -> VoiceLine {
        VoiceLine(
            id: id,
            event: event,
            action: action,
            text: id,
            audioFile: "\(id).mp3",
            addressed: addressed
        )
    }

    private static func requireLine(
        _ line: VoiceLine?,
        _ message: String
    ) throws -> VoiceLine {
        guard let line else { throw Failure(message) }
        return line
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
