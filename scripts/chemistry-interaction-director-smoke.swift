import Foundation

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    guard condition() else {
        fputs("FAIL  \(message)\n", stderr)
        exit(1)
    }
}

@main
private struct ChemistryInteractionDirectorSmoke {
    static func main() {
        require(CompanionDaypart(hour: 4) == .night, "04:00 should be night")
        require(CompanionDaypart(hour: 5) == .morning, "05:00 should be morning")
        require(CompanionDaypart(hour: 11) == .midday, "11:00 should be midday")
        require(CompanionDaypart(hour: 14) == .afternoon, "14:00 should be afternoon")
        require(CompanionDaypart(hour: 19) == .evening, "19:00 should be evening")
        require(CompanionDaypart(hour: 23) == .night, "23:00 should be night")

        let director = CompanionChemistryInteractionDirector()
        let calmContext = CompanionChemistryInteractionContext(
            hour: 21,
            relationshipTone: .calmPeer,
            chemistryLevel: 3,
            mood: .affectionate
        )
        require(calmContext.chemistryLevel == 1, "calm tone chemistry cap was ignored")

        let calmSingle = director.candidates(
            for: .singleTap,
            context: calmContext
        )
        let calmDouble = director.candidates(
            for: .doubleTap,
            context: calmContext
        )
        require(!calmSingle.isEmpty && !calmDouble.isEmpty, "calm mode lost its fallback")
        require(
            (calmSingle + calmDouble).allSatisfy {
                $0.moment.relationshipBoundary == .neutral
            },
            "calm mode admitted an intimate candidate"
        )

        let warmContext = CompanionChemistryInteractionContext(
            hour: 22,
            relationshipTone: .warmSupport,
            chemistryLevel: 99,
            mood: .affectionate
        )
        require(warmContext.chemistryLevel == 2, "warm tone chemistry cap was ignored")
        let warmCandidates = director.candidates(
            for: .doubleTap,
            context: warmContext
        )
        require(
            warmCandidates.allSatisfy {
                $0.moment.relationshipBoundary.rawValue
                    <= CompanionMomentRelationshipBoundary.warm.rawValue
            },
            "warm mode admitted playful or romantic material"
        )

        let playfulContext = CompanionChemistryInteractionContext(
            hour: 20,
            relationshipTone: .playfulSpark,
            chemistryLevel: 3,
            mood: .playful
        )
        let playfulCandidates = director.candidates(
            for: .doubleTap,
            context: playfulContext
        )
        require(
            playfulCandidates.contains { $0.moment == .vanity },
            "playful mode did not gain playful variety"
        )
        require(
            !playfulCandidates.contains {
                $0.moment.relationshipBoundary == .romantic
            },
            "playful mode admitted romance-only material"
        )

        let lowRomanceContext = CompanionChemistryInteractionContext(
            hour: 23,
            relationshipTone: .romanceLite,
            chemistryLevel: 1,
            mood: .affectionate
        )
        require(
            !director.candidates(for: .singleTap, context: lowRomanceContext)
                .contains { $0.moment == .kiss },
            "romantic moment unlocked before its chemistry threshold"
        )

        let highRomanceContext = CompanionChemistryInteractionContext(
            hour: 23,
            relationshipTone: .romanceLite,
            chemistryLevel: 3,
            mood: .affectionate
        )
        require(
            director.candidates(for: .singleTap, context: highRomanceContext)
                .contains { $0.moment == .kiss },
            "romance-lite did not unlock its explicitly gated moment"
        )
        require(
            director.candidates(for: .doubleTap, context: highRomanceContext)
                .contains { $0.moment == .underseaRoom },
            "level-three romance candidate was not available"
        )

        let deterministicA = director.select(
            for: .doubleTap,
            context: highRomanceContext,
            seed: 0xC0FFEE
        )
        let deterministicB = director.select(
            for: .doubleTap,
            context: highRomanceContext,
            seed: 0xC0FFEE
        )
        require(deterministicA == deterministicB, "seeded selection was not deterministic")
        require(
            deterministicA?.selected.kind != .action,
            "double tap selected a short action"
        )

        let singleSelection = director.select(
            for: .singleTap,
            context: highRomanceContext,
            seed: 7
        )
        require(
            singleSelection?.selected.kind == .action,
            "single tap selected a long scene"
        )

        guard let first = director.select(
            for: .doubleTap,
            context: playfulContext,
            seed: 42
        ) else {
            fputs("FAIL  director returned no selection\n", stderr)
            exit(1)
        }
        let recentContext = CompanionChemistryInteractionContext(
            hour: 20,
            relationshipTone: .playfulSpark,
            chemistryLevel: 3,
            mood: .playful,
            recentMomentKeys: [first.selected.key, first.selected.key]
        )
        guard let afterRecent = director.select(
            for: .doubleTap,
            context: recentContext,
            seed: 42
        ) else {
            fputs("FAIL  director returned no selection after recent history\n", stderr)
            exit(1)
        }
        require(
            afterRecent.candidates.first { $0.moment == first.selected }?.isRecent == true,
            "recent key was not identified"
        )
        require(
            afterRecent.selected != first.selected,
            "fresh candidate did not outrank a repeated moment"
        )
        require(
            afterRecent.candidates.allSatisfy { $0.weight > 0 },
            "a candidate received a zero weight"
        )

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let injectedDate = Date(timeIntervalSince1970: 1_800_021_600)
        let dateContext = CompanionChemistryInteractionContext(
            at: injectedDate,
            calendar: utc,
            relationshipTone: .warmSupport,
            chemistryLevel: 1,
            mood: .focused
        )
        require(
            dateContext.hour == utc.component(.hour, from: injectedDate),
            "injected date/calendar was not used"
        )

        print("PASS  injected daypart boundaries")
        print("PASS  calm/warm relationship safety")
        print("PASS  chemistry-gated candidate layers")
        print("PASS  single/double moment families")
        print("PASS  seeded weighted selection")
        print("PASS  recent-moment avoidance")
    }
}
