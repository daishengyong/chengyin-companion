/// Semantic mood chosen when a microgame leaves its ephemeral play session.
///
/// App targets project this value into animation, copy and audio. Keeping the
/// intent in Core lets every UI and future content pack observe the same
/// positive, penalty-free completion contract without importing presentation
/// frameworks.
public enum CompanionMicrogameCompletionMood: String, CaseIterable, Sendable {
    case playful
    case affectionate
    case celebrating
}

/// Built-in audiovisual reward family for a completed microgame.
///
/// `adaptiveAffection` deliberately leaves the final heart/kiss choice to the
/// user's relationship-tone ceiling in the App layer.
public enum CompanionMicrogameRewardBeat: String, CaseIterable, Sendable {
    case cheer
    case adaptiveAffection
    case twirl
    case heart
    case jump
    case kitchen
}

/// Positive relationship memory granted by a completed game. A failed or
/// manually-ended game never produces debt, loss or a negative memory.
public struct CompanionMicrogameRelationshipReward: Equatable, Sendable {
    public let momentID: String
    public let bond: UInt64
    public let chemistry: Int
    public let mementoID: String

    public init(
        momentID: String,
        bond: UInt64,
        chemistry: Int,
        mementoID: String
    ) {
        self.momentID = momentID
        self.bond = bond
        self.chemistry = chemistry
        self.mementoID = mementoID
    }
}

/// Content-free result consumed by the App after the runtime has ended a game.
public struct CompanionMicrogameCompletionPlan: Equatable, Sendable {
    public let game: CompanionMicrogameKind
    public let won: Bool
    public let announce: Bool
    public let mood: CompanionMicrogameCompletionMood
    public let rewardBeat: CompanionMicrogameRewardBeat?
    public let relationshipReward: CompanionMicrogameRelationshipReward?
    public let restoreImmediately: Bool
    public let resumeDelay: Double

    public init(
        game: CompanionMicrogameKind,
        won: Bool,
        announce: Bool,
        mood: CompanionMicrogameCompletionMood,
        rewardBeat: CompanionMicrogameRewardBeat?,
        relationshipReward: CompanionMicrogameRelationshipReward?,
        restoreImmediately: Bool,
        resumeDelay: Double
    ) {
        self.game = game
        self.won = won
        self.announce = announce
        self.mood = mood
        self.rewardBeat = rewardBeat
        self.relationshipReward = relationshipReward
        self.restoreImmediately = restoreImmediately
        self.resumeDelay = resumeDelay
    }
}

/// Deterministic, privacy-free completion policy shared by all six built-in
/// games. It owns reward semantics and return timing, not media or windows.
public struct CompanionMicrogameCompletionPolicy: Sendable {
    public init() {}

    public func plan(
        for game: CompanionMicrogameKind,
        won: Bool,
        announce: Bool = true
    ) -> CompanionMicrogameCompletionPlan {
        guard won else {
            return CompanionMicrogameCompletionPlan(
                game: game,
                won: false,
                announce: announce,
                mood: .affectionate,
                rewardBeat: nil,
                relationshipReward: nil,
                restoreImmediately: true,
                resumeDelay: announce && game == .catchPet ? 3.6 : (announce ? 4.0 : 0.2)
            )
        }

        let specification = rewardSpecification(for: game)
        return CompanionMicrogameCompletionPlan(
            game: game,
            won: true,
            announce: announce,
            mood: specification.mood,
            rewardBeat: specification.beat,
            relationshipReward: specification.relationship,
            restoreImmediately: false,
            resumeDelay: 0
        )
    }

    private func rewardSpecification(
        for game: CompanionMicrogameKind
    ) -> (
        mood: CompanionMicrogameCompletionMood,
        beat: CompanionMicrogameRewardBeat,
        relationship: CompanionMicrogameRelationshipReward
    ) {
        switch game {
        case .catchPet:
            return (
                .playful,
                .cheer,
                .init(
                    momentID: "game.catch.won",
                    bond: 2,
                    chemistry: 1,
                    mementoID: "game.catch.crown"
                )
            )
        case .hideAndSeek:
            return (
                .affectionate,
                .adaptiveAffection,
                .init(
                    momentID: "game.hide.won",
                    bond: 2,
                    chemistry: 1,
                    mementoID: "game.hide.peek"
                )
            )
        case .gestureCombo:
            return (
                .celebrating,
                .twirl,
                .init(
                    momentID: "game.combo.won",
                    bond: 2,
                    chemistry: 1,
                    mementoID: "game.combo.secret"
                )
            )
        case .heartTrace:
            return (
                .celebrating,
                .heart,
                .init(
                    momentID: "game.trace.won",
                    bond: 2,
                    chemistry: 2,
                    mementoID: "game.trace.heart"
                )
            )
        case .rhythm:
            return (
                .celebrating,
                .jump,
                .init(
                    momentID: "game.rhythm.won",
                    bond: 2,
                    chemistry: 2,
                    mementoID: "game.rhythm.eight"
                )
            )
        case .feed:
            return (
                .celebrating,
                .kitchen,
                .init(
                    momentID: "game.feed.won",
                    bond: 2,
                    chemistry: 1,
                    mementoID: "game.feed.kitchen"
                )
            )
        }
    }
}
