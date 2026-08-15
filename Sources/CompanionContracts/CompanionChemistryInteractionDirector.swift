import Foundation

/// The two direct interactions currently directed by the session chemistry model.
public enum CompanionDirectedInteraction: String, Equatable, Sendable {
    case singleTap
    case doubleTap
}

/// A small, explicit time model keeps selection independent from wall-clock access.
public enum CompanionDaypart: String, CaseIterable, Equatable, Sendable {
    case night
    case morning
    case midday
    case afternoon
    case evening

    public init(hour: Int) {
        switch min(max(hour, 0), 23) {
        case 5..<11:
            self = .morning
        case 11..<14:
            self = .midday
        case 14..<19:
            self = .afternoon
        case 19..<23:
            self = .evening
        default:
            self = .night
        }
    }
}

/// A presentation-independent subset of `PetMood`.
///
/// Keeping this type in the director avoids making the pure selection model depend
/// on observable UI state. The view model can map its current mood at integration.
public enum CompanionInteractionMood: String, CaseIterable, Equatable, Sendable {
    case calm
    case curious
    case playful
    case affectionate
    case focused
    case sleepy
    case celebrating
}

public enum CompanionDirectedMomentKind: String, Equatable, Sendable {
    case action
    case scene
    case miniScene
}

public enum CompanionMomentRelationshipBoundary: Int, Equatable, Sendable {
    case neutral
    case warm
    case playful
    case romantic
}

/// Stable model-layer moments that can be mapped to the app's existing private
/// `PetMoment`. Keys intentionally match the current recent-moment storage format.
public enum CompanionDirectedPetMoment: String, CaseIterable, Equatable, Hashable, Sendable {
    case drink = "action:0"
    case stretch = "action:1"
    case clap = "action:2"
    case jump = "action:3"
    case twirl = "action:4"
    case laugh = "action:5"
    case heart = "action:6"
    case kiss = "action:7"
    case cheer = "action:8"

    case moonDance = "scene:moon-dance"
    case bedtime = "scene:bedtime"
    case lunarOrbit = "scene:lunar-orbit"
    case underseaRoom = "scene:undersea-room"
    case timeCafe = "scene:time-cafe"
    case rainPortal = "scene:rain-portal"

    case kitchen = "mini:kitchen"
    case bed = "mini:bed"
    case workout = "mini:workout"
    case vanity = "mini:vanity"

    public var key: String {
        rawValue
    }

    public var kind: CompanionDirectedMomentKind {
        if rawValue.hasPrefix("action:") {
            return .action
        }
        if rawValue.hasPrefix("scene:") {
            return .scene
        }
        return .miniScene
    }

    public var relationshipBoundary: CompanionMomentRelationshipBoundary {
        switch self {
        case .drink, .stretch, .clap, .cheer, .rainPortal, .workout:
            .neutral
        case .jump, .twirl, .laugh, .heart, .kitchen:
            .warm
        case .moonDance, .timeCafe, .vanity:
            .playful
        case .kiss, .bedtime, .lunarOrbit, .underseaRoom, .bed:
            .romantic
        }
    }
}

/// Layers are selection precedence, while weight chooses variety within a layer.
public enum CompanionMomentCandidateTier: Int, CaseIterable, Equatable, Sendable {
    case spotlight
    case contextual
    case fallback
}

public struct CompanionMomentCandidate: Equatable, Sendable {
    public let moment: CompanionDirectedPetMoment
    public let tier: CompanionMomentCandidateTier
    public let weight: UInt64
    public let isRecent: Bool
    public let matchedDaypart: Bool
    public let matchedMood: Bool
}

public struct CompanionChemistryInteractionContext: Equatable, Sendable {
    public let hour: Int
    public let daypart: CompanionDaypart
    public let relationshipTone: CompanionRelationshipTone
    public let chemistryLevel: Int
    public let mood: CompanionInteractionMood
    public let recentMomentKeys: [String]

    public init(
        hour: Int,
        relationshipTone: CompanionRelationshipTone,
        chemistryLevel: Int,
        mood: CompanionInteractionMood = .calm,
        recentMomentKeys: [String] = []
    ) {
        let safeHour = min(max(hour, 0), 23)
        self.hour = safeHour
        self.daypart = CompanionDaypart(hour: safeHour)
        self.relationshipTone = relationshipTone
        self.chemistryLevel = Self.clampedChemistry(
            chemistryLevel,
            for: relationshipTone
        )
        self.mood = mood
        self.recentMomentKeys = Array(recentMomentKeys.suffix(8))
    }

    public init(
        at date: Date,
        calendar: Calendar = .current,
        relationshipTone: CompanionRelationshipTone,
        chemistryLevel: Int,
        mood: CompanionInteractionMood = .calm,
        recentMomentKeys: [String] = []
    ) {
        self.init(
            hour: calendar.component(.hour, from: date),
            relationshipTone: relationshipTone,
            chemistryLevel: chemistryLevel,
            mood: mood,
            recentMomentKeys: recentMomentKeys
        )
    }

    private static func clampedChemistry(
        _ level: Int,
        for tone: CompanionRelationshipTone
    ) -> Int {
        let toneCap: Int
        switch tone {
        case .calmPeer:
            toneCap = 1
        case .warmSupport:
            toneCap = 2
        case .playfulSpark, .romanceLite:
            toneCap = 3
        }
        return min(max(level, 0), toneCap)
    }
}

public struct CompanionChemistrySelection: Equatable, Sendable {
    public let selected: CompanionDirectedPetMoment
    public let selectedTier: CompanionMomentCandidateTier
    public let candidates: [CompanionMomentCandidate]
}

/// Pure, offline interaction selection for a single session.
///
/// The director has no clock, persistence, network, commerce, streak, or negative
/// relationship behavior. Callers inject time, recent keys, and randomness.
public struct CompanionChemistryInteractionDirector: Sendable {
    public init() {}

    public func candidates(
        for interaction: CompanionDirectedInteraction,
        context: CompanionChemistryInteractionContext
    ) -> [CompanionMomentCandidate] {
        let recentKeys = Array(context.recentMomentKeys.suffix(6))
        let recentKeySet = Set(recentKeys)
        let recencyByKey = Dictionary(
            recentKeys.reversed().enumerated().map {
                ($0.element, $0.offset)
            },
            uniquingKeysWith: { newestIndex, _ in newestIndex }
        )

        return Self.recipes
            .filter { recipe in
                recipe.interaction == interaction
                    && recipe.minimumChemistry <= context.chemistryLevel
                    && recipe.boundary.isAllowed(by: context.relationshipTone)
            }
            .map { recipe in
                let matchedDaypart = recipe.dayparts.contains(context.daypart)
                let matchedMood = recipe.moods.contains(context.mood)
                let affinity = (matchedDaypart ? 2 : 0) + (matchedMood ? 3 : 0)
                let tier: CompanionMomentCandidateTier
                switch affinity {
                case 4...:
                    tier = .spotlight
                case 2...:
                    tier = .contextual
                default:
                    tier = .fallback
                }

                let chemistryLift = max(
                    0,
                    context.chemistryLevel - recipe.minimumChemistry
                )
                let unpenalizedWeight = recipe.baseWeight
                    + UInt64(affinity * 2)
                    + UInt64(chemistryLift)
                let adjustedWeight: UInt64
                if let recency = recencyByKey[recipe.moment.key] {
                    let divisors: [UInt64] = [8, 6, 4, 3, 2, 2]
                    adjustedWeight = max(
                        1,
                        unpenalizedWeight / divisors[min(recency, divisors.count - 1)]
                    )
                } else {
                    adjustedWeight = unpenalizedWeight
                }

                return CompanionMomentCandidate(
                    moment: recipe.moment,
                    tier: tier,
                    weight: adjustedWeight,
                    isRecent: recentKeySet.contains(recipe.moment.key),
                    matchedDaypart: matchedDaypart,
                    matchedMood: matchedMood
                )
            }
            .sorted(by: Self.candidateOrder)
    }

    public func select<R: RandomNumberGenerator>(
        for interaction: CompanionDirectedInteraction,
        context: CompanionChemistryInteractionContext,
        using randomNumberGenerator: inout R
    ) -> CompanionChemistrySelection? {
        let rankedCandidates = candidates(for: interaction, context: context)
        guard !rankedCandidates.isEmpty else {
            return nil
        }

        var pool: [CompanionMomentCandidate] = []
        for tier in CompanionMomentCandidateTier.allCases {
            pool = rankedCandidates.filter { $0.tier == tier && !$0.isRecent }
            if !pool.isEmpty {
                break
            }
        }

        if pool.isEmpty {
            for tier in CompanionMomentCandidateTier.allCases {
                pool = rankedCandidates.filter { $0.tier == tier }
                if !pool.isEmpty {
                    break
                }
            }
        }

        guard let selectedCandidate = weightedChoice(
            from: pool,
            using: &randomNumberGenerator
        ) else {
            return nil
        }

        return CompanionChemistrySelection(
            selected: selectedCandidate.moment,
            selectedTier: selectedCandidate.tier,
            candidates: rankedCandidates
        )
    }

    public func select(
        for interaction: CompanionDirectedInteraction,
        context: CompanionChemistryInteractionContext,
        seed: UInt64
    ) -> CompanionChemistrySelection? {
        var generator = CompanionSeededRandomNumberGenerator(seed: seed)
        return select(
            for: interaction,
            context: context,
            using: &generator
        )
    }

    private func weightedChoice<R: RandomNumberGenerator>(
        from candidates: [CompanionMomentCandidate],
        using randomNumberGenerator: inout R
    ) -> CompanionMomentCandidate? {
        guard !candidates.isEmpty else {
            return nil
        }

        let totalWeight = candidates.reduce(UInt64(0)) { partial, candidate in
            partial + candidate.weight
        }
        guard totalWeight > 0 else {
            return candidates.first
        }

        let rejectionLimit = UInt64.max - (UInt64.max % totalWeight)
        var randomValue = randomNumberGenerator.next()
        while randomValue >= rejectionLimit {
            randomValue = randomNumberGenerator.next()
        }
        var target = randomValue % totalWeight

        for candidate in candidates {
            if target < candidate.weight {
                return candidate
            }
            target -= candidate.weight
        }
        return candidates.last
    }

    private static func candidateOrder(
        _ lhs: CompanionMomentCandidate,
        _ rhs: CompanionMomentCandidate
    ) -> Bool {
        if lhs.tier != rhs.tier {
            return lhs.tier.rawValue < rhs.tier.rawValue
        }
        if lhs.isRecent != rhs.isRecent {
            return !lhs.isRecent
        }
        if lhs.weight != rhs.weight {
            return lhs.weight > rhs.weight
        }
        return lhs.moment.key < rhs.moment.key
    }

    private static let recipes: [MomentRecipe] = [
        // Direct taps are acknowledgements, not scheduled-care delivery. Keep
        // hydration, movement and time-themed beats in the care scheduler or
        // explicit magic-wand palette so a click never sounds like an alarm.
        // Single tap remains short, responsive and action-oriented.
        MomentRecipe(
            .clap, .singleTap, .neutral, 0, 6,
            [.midday, .evening],
            [.celebrating]
        ),
        MomentRecipe(
            .cheer, .singleTap, .neutral, 0, 8,
            [.morning, .afternoon],
            [.focused, .celebrating]
        ),
        MomentRecipe(
            .laugh, .singleTap, .warm, 1, 7,
            [.midday, .evening],
            [.curious, .playful]
        ),
        MomentRecipe(
            .jump, .singleTap, .warm, 1, 6,
            [.afternoon],
            [.playful, .celebrating]
        ),
        MomentRecipe(
            .twirl, .singleTap, .warm, 1, 6,
            [.afternoon, .evening],
            [.playful]
        ),
        MomentRecipe(
            .heart, .singleTap, .warm, 1, 7,
            [.midday, .evening, .night],
            [.affectionate, .celebrating]
        ),
        MomentRecipe(
            .kiss, .singleTap, .romantic, 2, 5,
            [.evening, .night],
            [.affectionate]
        ),

        // Double tap opens a longer mini-scene or world beat.
        MomentRecipe(
            .rainPortal, .doubleTap, .neutral, 0, 8,
            [.morning, .afternoon, .night],
            [.calm, .curious, .sleepy]
        ),
        MomentRecipe(
            .kitchen, .doubleTap, .warm, 1, 7,
            [.morning, .midday],
            [.calm, .affectionate]
        ),
        MomentRecipe(
            .vanity, .doubleTap, .playful, 1, 6,
            [.afternoon, .evening],
            [.curious, .playful]
        ),
        MomentRecipe(
            .moonDance, .doubleTap, .playful, 2, 5,
            [.evening, .night],
            [.playful, .celebrating]
        ),
        MomentRecipe(
            .bed, .doubleTap, .romantic, 2, 5,
            [.evening, .night],
            [.sleepy, .affectionate]
        ),
        MomentRecipe(
            .bedtime, .doubleTap, .romantic, 2, 4,
            [.night],
            [.sleepy]
        ),
        MomentRecipe(
            .lunarOrbit, .doubleTap, .romantic, 2, 5,
            [.evening, .night],
            [.affectionate, .playful]
        ),
        MomentRecipe(
            .underseaRoom, .doubleTap, .romantic, 3, 4,
            [.night],
            [.calm, .affectionate]
        )
    ]
}

private extension CompanionMomentRelationshipBoundary {
    func isAllowed(by tone: CompanionRelationshipTone) -> Bool {
        switch self {
        case .neutral:
            true
        case .warm:
            tone != .calmPeer
        case .playful:
            tone == .playfulSpark || tone == .romanceLite
        case .romantic:
            tone == .romanceLite
        }
    }
}

private struct MomentRecipe: Sendable {
    let moment: CompanionDirectedPetMoment
    let interaction: CompanionDirectedInteraction
    let boundary: CompanionMomentRelationshipBoundary
    let minimumChemistry: Int
    let baseWeight: UInt64
    let dayparts: Set<CompanionDaypart>
    let moods: Set<CompanionInteractionMood>

    init(
        _ moment: CompanionDirectedPetMoment,
        _ interaction: CompanionDirectedInteraction,
        _ boundary: CompanionMomentRelationshipBoundary,
        _ minimumChemistry: Int,
        _ baseWeight: UInt64,
        _ dayparts: Set<CompanionDaypart>,
        _ moods: Set<CompanionInteractionMood>
    ) {
        self.moment = moment
        self.interaction = interaction
        self.boundary = boundary
        self.minimumChemistry = minimumChemistry
        self.baseWeight = baseWeight
        self.dayparts = dayparts
        self.moods = moods
    }
}

/// SplitMix64 provides a small reproducible generator for tests and previews.
struct CompanionSeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
