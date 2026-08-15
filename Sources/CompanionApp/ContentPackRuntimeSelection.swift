import Foundation

#if canImport(CompanionContracts)
import CompanionContracts
#endif

/// Pure, caller-memory-driven selection over an immutable runtime catalog.
/// Installation, health mutation and playback side effects remain outside this
/// file, so locale, cooldown, recent-exclusion and weighting rules can evolve
/// without growing the manifest projection boundary.
extension ContentPackRuntimeCatalog {
    func videos(
        for trigger: String,
        preferredLocale: String
    ) -> [CompanionVideoAsset] {
        let candidates = videosByTrigger[trigger] ?? []
        let localeMatches = Self.bestLocaleMatches(
            candidates,
            preferredLocale: preferredLocale,
            localeTags: \.localeTags
        )
        return localeMatches.isEmpty ? candidates : localeMatches
    }

    func experiences(
        for trigger: String,
        preferredLocale: String
    ) -> [CompanionVideoSequence] {
        let candidates = sequencesByTrigger[trigger] ?? []
        return Self.bestLocaleMatches(
            candidates,
            preferredLocale: preferredLocale,
            localeTags: \.localeTags
        )
    }

    func selectExperience(
        for triggers: [String],
        preferredLocale: String,
        context: ContentPackSelectionContext = ContentPackSelectionContext(),
        fallbackTriggers: [String] = [],
        randomSeed: UInt64? = nil
    ) -> ContentPackExperienceSelection? {
        var generator = ContentPackRandomSource(seed: randomSeed)
        if let selection = selectExperience(
            for: triggers,
            preferredLocale: preferredLocale,
            context: context,
            usedFallbackTrigger: false,
            generator: &generator
        ) {
            return selection
        }
        return selectExperience(
            for: fallbackTriggers,
            preferredLocale: preferredLocale,
            context: context,
            usedFallbackTrigger: true,
            generator: &generator
        )
    }

    /// Selects a video using ordered trigger priority, strict locale matching,
    /// cooldowns, recent exclusion and weighted randomness.
    ///
    /// Pass a fixed `randomSeed` in tests or reproducible previews. Production
    /// callers should leave it `nil` to use system randomness. Playback memory
    /// is intentionally caller-owned; after a successful play, prepend the
    /// asset ID to `recentAssetIDs` and store its completion/start time in
    /// `lastPlayedAtByAssetID`.
    func select(
        for triggers: [String],
        preferredLocale: String,
        context: ContentPackSelectionContext = ContentPackSelectionContext(),
        fallbackTriggers: [String] = [],
        randomSeed: UInt64? = nil
    ) -> ContentPackVideoSelection? {
        var generator = ContentPackRandomSource(seed: randomSeed)
        if let selection = select(
            for: triggers,
            preferredLocale: preferredLocale,
            context: context,
            usedFallbackTrigger: false,
            generator: &generator
        ) {
            return selection
        }
        return select(
            for: fallbackTriggers,
            preferredLocale: preferredLocale,
            context: context,
            usedFallbackTrigger: true,
            generator: &generator
        )
    }

    func selectVideo(
        for triggers: [String],
        preferredLocale: String,
        context: ContentPackSelectionContext = ContentPackSelectionContext(),
        fallbackTriggers: [String] = [],
        randomSeed: UInt64? = nil
    ) -> CompanionVideoAsset? {
        select(
            for: triggers,
            preferredLocale: preferredLocale,
            context: context,
            fallbackTriggers: fallbackTriggers,
            randomSeed: randomSeed
        )?.asset
    }

    /// Compatibility API for existing call sites. New playback paths should
    /// use `selectVideo` so they can supply recent and cooldown memory.
    func firstVideo(
        for triggers: [String],
        preferredLocale: String
    ) -> CompanionVideoAsset? {
        for trigger in triggers {
            if let match = videos(
                for: trigger,
                preferredLocale: preferredLocale
            ).first {
                return match
            }
        }
        return nil
    }

    private func select<RNG: RandomNumberGenerator>(
        for triggers: [String],
        preferredLocale: String,
        context: ContentPackSelectionContext,
        usedFallbackTrigger: Bool,
        generator: inout RNG
    ) -> ContentPackVideoSelection? {
        guard !triggers.isEmpty else { return nil }
        let recentIDs = Set(
            context.recentAssetIDs.prefix(context.recentExclusionLimit)
        )

        for trigger in triggers {
            let candidates = Self.bestLocaleMatches(
                videosByTrigger[trigger] ?? [],
                preferredLocale: preferredLocale,
                localeTags: \.localeTags
            )
            let eligible = candidates.filter {
                !recentIDs.contains($0.id)
                    && !Self.isCoolingDown($0, context: context)
            }
            guard !eligible.isEmpty else { continue }
            let asset = Self.weightedChoice(
                from: eligible,
                generator: &generator
            )
            return ContentPackVideoSelection(
                asset: asset,
                trigger: trigger,
                usedFallbackTrigger: usedFallbackTrigger
            )
        }
        return nil
    }

    private func selectExperience<RNG: RandomNumberGenerator>(
        for triggers: [String],
        preferredLocale: String,
        context: ContentPackSelectionContext,
        usedFallbackTrigger: Bool,
        generator: inout RNG
    ) -> ContentPackExperienceSelection? {
        guard !triggers.isEmpty else { return nil }
        let recentIDs = Set(
            context.recentAssetIDs.prefix(context.recentExclusionLimit)
        )
        for trigger in triggers {
            let candidates = Self.bestLocaleMatches(
                sequencesByTrigger[trigger] ?? [],
                preferredLocale: preferredLocale,
                localeTags: \.localeTags
            )
            let eligible = candidates.filter {
                !recentIDs.contains($0.id)
                    && !Self.isCoolingDown($0, context: context)
            }
            guard !eligible.isEmpty else { continue }
            return ContentPackExperienceSelection(
                sequence: Self.weightedSequenceChoice(
                    from: eligible,
                    generator: &generator
                ),
                trigger: trigger,
                usedFallbackTrigger: usedFallbackTrigger
            )
        }
        return nil
    }

    private static func isCoolingDown(
        _ asset: CompanionVideoAsset,
        context: ContentPackSelectionContext
    ) -> Bool {
        guard asset.cooldownSeconds > 0,
              let lastPlayedAt = context.lastPlayedAtByAssetID[asset.id] else {
            return false
        }
        let elapsed = context.now.timeIntervalSince(lastPlayedAt)
        return !elapsed.isFinite
            || elapsed < TimeInterval(asset.cooldownSeconds)
    }

    private static func isCoolingDown(
        _ sequence: CompanionVideoSequence,
        context: ContentPackSelectionContext
    ) -> Bool {
        guard sequence.cooldownSeconds > 0,
              let lastPlayedAt = context.lastPlayedAtByAssetID[sequence.id] else {
            return false
        }
        let elapsed = context.now.timeIntervalSince(lastPlayedAt)
        return !elapsed.isFinite
            || elapsed < TimeInterval(sequence.cooldownSeconds)
    }

    private static func weightedChoice<RNG: RandomNumberGenerator>(
        from candidates: [CompanionVideoAsset],
        generator: inout RNG
    ) -> CompanionVideoAsset {
        precondition(!candidates.isEmpty)
        let totalWeight = candidates.reduce(0) { $0 + $1.weight }
        guard totalWeight.isFinite, totalWeight > 0 else {
            return candidates[0]
        }

        let unit = Double(generator.next()) / (Double(UInt64.max) + 1)
        let threshold = unit * totalWeight
        var accumulated = 0.0
        for candidate in candidates {
            accumulated += candidate.weight
            if threshold < accumulated {
                return candidate
            }
        }
        return candidates[candidates.count - 1]
    }

    private static func weightedSequenceChoice<RNG: RandomNumberGenerator>(
        from candidates: [CompanionVideoSequence],
        generator: inout RNG
    ) -> CompanionVideoSequence {
        precondition(!candidates.isEmpty)
        let totalWeight = candidates.reduce(0) { $0 + $1.weight }
        guard totalWeight.isFinite, totalWeight > 0 else {
            return candidates[0]
        }

        let unit = Double(generator.next()) / (Double(UInt64.max) + 1)
        let threshold = unit * totalWeight
        var accumulated = 0.0
        for candidate in candidates {
            accumulated += candidate.weight
            if threshold < accumulated {
                return candidate
            }
        }
        return candidates[candidates.count - 1]
    }

    private static func bestLocaleMatches<Value>(
        _ candidates: [Value],
        preferredLocale: String,
        localeTags: (Value) -> [String]
    ) -> [Value] {
        guard !candidates.isEmpty else { return [] }
        let preferredIsEmpty = preferredLocale
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let ranked = candidates.enumerated().compactMap { index, candidate in
            let tags = localeTags(candidate)
            if tags.isEmpty || preferredIsEmpty {
                return (index, candidate, 0)
            }
            let score = tags.compactMap {
                CompanionLocaleResolutionPolicy.compatibilityScore(
                    candidate: $0,
                    preferred: preferredLocale
                )
            }.max()
            return score.map { (index, candidate, $0) }
        }
        guard let highest = ranked.map(\.2).max() else { return [] }
        return ranked.filter { $0.2 == highest }.map(\.1)
    }
}

/// SplitMix64 is stable across Swift and OS releases, while the system branch
/// remains cryptographically seeded by Swift's standard random generator.
private struct ContentPackRandomSource: RandomNumberGenerator {
    private var deterministicState: UInt64?
    private var system = SystemRandomNumberGenerator()

    init(seed: UInt64?) {
        deterministicState = seed
    }

    mutating func next() -> UInt64 {
        guard var state = deterministicState else {
            return system.next()
        }
        state &+= 0x9E3779B97F4A7C15
        deterministicState = state
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
