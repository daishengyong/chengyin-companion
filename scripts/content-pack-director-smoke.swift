import Darwin
import Foundation

@main
struct ContentPackDirectorSmoke {
    @MainActor
    static func main() throws {
        setbuf(stdout, nil)
        try deterministicSeedAndWeighting()
        print("PASS  deterministic seed and weighted choice")
        try recentAssetsAreExcluded()
        print("PASS  recent exclusion")
        try cooldownIsEnforced()
        print("PASS  cooldown and boundary")
        try localeIsStrictAndScriptAware()
        print("PASS  locale and script matching")
        try fallbackTriggerIsExplicit()
        print("PASS  fallback trigger and safe nil")
        try orderedTriggerPriorityIsPreserved()
        print("PASS  ordered trigger priority")
        try firstVideoRemainsCompatible()
        print("PASS  firstVideo compatibility")
        try v2ExperienceSequenceIsResolved()
        print("PASS  v2 ordered experience sequence")
        try sequenceCursorRejectsStaleCallbacks()
        print("PASS  sequence cursor lifecycle")
        try contentSequenceRuntimeOwnsReplacementAndCache()
        print("PASS  content sequence session ownership")
        print("Content pack director smoke checks passed (10/10).")
    }

    private static func deterministicSeedAndWeighting() throws {
        let catalog = makeCatalog(
            packID: "cc.chengyin.pack.weighted",
            locales: ["en"],
            assets: [
                asset(id: "light", trigger: "singleTap", weight: 1),
                asset(id: "heavy", trigger: "singleTap", weight: 9)
            ]
        )
        let context = ContentPackSelectionContext(
            now: Date(timeIntervalSince1970: 2_000_000_000)
        )
        let first = catalog.selectVideo(
            for: ["singleTap"],
            preferredLocale: "en-US",
            context: context,
            randomSeed: 42
        )
        let second = catalog.selectVideo(
            for: ["singleTap"],
            preferredLocale: "en-US",
            context: context,
            randomSeed: 42
        )
        try require(first?.id == second?.id, "fixed seed was not deterministic")

        var heavySelections = 0
        for seed in UInt64(0)..<UInt64(1_000) {
            let selected = catalog.selectVideo(
                for: ["singleTap"],
                preferredLocale: "en-US",
                context: context,
                randomSeed: seed
            )
            if selected?.id.hasSuffix(":heavy") == true {
                heavySelections += 1
            }
        }
        try require(
            heavySelections > 820,
            "9:1 weight did not materially affect selection (\(heavySelections)/1000)"
        )
    }

    private static func recentAssetsAreExcluded() throws {
        let catalog = makeCatalog(
            packID: "cc.chengyin.pack.recent",
            locales: ["en"],
            assets: [
                asset(id: "a", trigger: "doubleTap"),
                asset(id: "b", trigger: "doubleTap")
            ]
        )
        let recentA = "cc.chengyin.pack.recent@1.0.0:a"
        let selected = catalog.selectVideo(
            for: ["doubleTap"],
            preferredLocale: "en",
            context: ContentPackSelectionContext(
                now: Date(timeIntervalSince1970: 2_000_000_000),
                recentAssetIDs: [recentA],
                recentExclusionLimit: 6
            ),
            randomSeed: 7
        )
        try require(
            selected?.id == "cc.chengyin.pack.recent@1.0.0:b",
            "recent asset was selected again"
        )

        let noCandidate = catalog.selectVideo(
            for: ["doubleTap"],
            preferredLocale: "en",
            context: ContentPackSelectionContext(
                now: Date(timeIntervalSince1970: 2_000_000_000),
                recentAssetIDs: [
                    "cc.chengyin.pack.recent@1.0.0:a",
                    "cc.chengyin.pack.recent@1.0.0:b"
                ]
            ),
            randomSeed: 7
        )
        try require(noCandidate == nil, "recent exclusion was silently relaxed")
    }

    private static func cooldownIsEnforced() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let catalog = makeCatalog(
            packID: "cc.chengyin.pack.cooldown",
            locales: ["en"],
            assets: [
                asset(
                    id: "cooling",
                    trigger: "taskCompleted",
                    weight: 100,
                    cooldownSeconds: 60
                ),
                asset(
                    id: "ready",
                    trigger: "taskCompleted",
                    weight: 1,
                    cooldownSeconds: 60
                )
            ]
        )
        let coolingID = "cc.chengyin.pack.cooldown@1.0.0:cooling"
        let selected = catalog.selectVideo(
            for: ["taskCompleted"],
            preferredLocale: "en",
            context: ContentPackSelectionContext(
                now: now,
                lastPlayedAtByAssetID: [
                    coolingID: now.addingTimeInterval(-59.999)
                ]
            ),
            randomSeed: 1
        )
        try require(
            selected?.id.hasSuffix(":ready") == true,
            "asset was selected during cooldown"
        )

        let atBoundary = catalog.selectVideo(
            for: ["taskCompleted"],
            preferredLocale: "en",
            context: ContentPackSelectionContext(
                now: now,
                lastPlayedAtByAssetID: [
                    coolingID: now.addingTimeInterval(-60)
                ]
            ),
            randomSeed: 1
        )
        try require(
            atBoundary?.id.hasSuffix(":cooling") == true,
            "asset did not become eligible at the cooldown boundary"
        )

        let futurePlayback = catalog.selectVideo(
            for: ["taskCompleted"],
            preferredLocale: "en",
            context: ContentPackSelectionContext(
                now: now,
                lastPlayedAtByAssetID: [
                    coolingID: now.addingTimeInterval(10)
                ]
            ),
            randomSeed: 1
        )
        try require(
            futurePlayback?.id.hasSuffix(":ready") == true,
            "clock rollback incorrectly bypassed cooldown"
        )
    }

    private static func localeIsStrictAndScriptAware() throws {
        let catalog = ContentPackRuntimeCatalog(
            activePacks: [
                makePack(
                    packID: "cc.chengyin.pack.simplified",
                    locales: ["zh-Hans"],
                    assets: [asset(id: "scene", trigger: "evening")]
                ),
                makePack(
                    packID: "cc.chengyin.pack.traditional",
                    locales: ["zh-Hant"],
                    assets: [asset(id: "scene", trigger: "evening")]
                ),
                makePack(
                    packID: "cc.chengyin.pack.english",
                    locales: ["en"],
                    assets: [asset(id: "scene", trigger: "evening")]
                )
            ]
        )
        let context = ContentPackSelectionContext(
            now: Date(timeIntervalSince1970: 2_000_000_000)
        )
        let traditional = catalog.selectVideo(
            for: ["evening"],
            preferredLocale: "zh-TW",
            context: context,
            randomSeed: 0
        )
        try require(
            traditional?.packReference?.packID
                == "cc.chengyin.pack.traditional",
            "traditional Chinese selected the wrong script"
        )

        let simplified = catalog.selectVideo(
            for: ["evening"],
            preferredLocale: "zh_CN",
            context: context,
            randomSeed: 0
        )
        try require(
            simplified?.packReference?.packID
                == "cc.chengyin.pack.simplified",
            "simplified Chinese selected the wrong script"
        )

        let unsupported = catalog.selectVideo(
            for: ["evening"],
            preferredLocale: "fr-FR",
            context: context,
            randomSeed: 0
        )
        try require(
            unsupported == nil,
            "director played content in an unsupported language"
        )
    }

    private static func fallbackTriggerIsExplicit() throws {
        let catalog = ContentPackRuntimeCatalog(
            activePacks: [
                makePack(
                    packID: "cc.chengyin.pack.primary",
                    locales: ["en"],
                    assets: [asset(id: "primary", trigger: "singleTap")]
                ),
                makePack(
                    packID: "cc.chengyin.pack.fallback",
                    locales: ["fr"],
                    assets: [asset(id: "fallback", trigger: "idle")]
                )
            ]
        )
        let selection = catalog.select(
            for: ["singleTap"],
            preferredLocale: "fr-FR",
            context: ContentPackSelectionContext(
                now: Date(timeIntervalSince1970: 2_000_000_000)
            ),
            fallbackTriggers: ["idle"],
            randomSeed: 123
        )
        try require(selection?.trigger == "idle", "fallback trigger was not used")
        try require(
            selection?.usedFallbackTrigger == true,
            "fallback selection was not identified"
        )
        try require(
            selection?.asset.id.hasSuffix(":fallback") == true,
            "fallback selected the wrong asset"
        )

        let noCandidate = catalog.selectVideo(
            for: ["singleTap"],
            preferredLocale: "de-DE",
            fallbackTriggers: ["idle"],
            randomSeed: 123
        )
        try require(noCandidate == nil, "missing content did not safely return nil")
    }

    private static func orderedTriggerPriorityIsPreserved() throws {
        let catalog = makeCatalog(
            packID: "cc.chengyin.pack.priority",
            locales: ["en"],
            assets: [
                asset(id: "first", trigger: "taskCompleted", weight: 1),
                asset(id: "second", trigger: "evening", weight: 1_000)
            ]
        )
        let selection = catalog.select(
            for: ["taskCompleted", "evening"],
            preferredLocale: "en",
            randomSeed: 99
        )
        try require(
            selection?.trigger == "taskCompleted",
            "later trigger overrode caller priority"
        )
    }

    private static func firstVideoRemainsCompatible() throws {
        let catalog = makeCatalog(
            packID: "cc.chengyin.pack.compatibility",
            locales: ["en"],
            assets: [asset(id: "legacy", trigger: "doubleTap")]
        )
        let selected = catalog.firstVideo(
            for: ["missing", "doubleTap"],
            preferredLocale: "en-US"
        )
        try require(
            selected?.id.hasSuffix(":legacy") == true,
            "firstVideo compatibility path changed"
        )
    }

    private static func v2ExperienceSequenceIsResolved() throws {
        let assets = [
            asset(id: "enter", trigger: "idle"),
            asset(id: "react", trigger: "idle")
        ]
        let experience = ContentPackExperience(
            id: "ritual.shared-win",
            kind: .ritual,
            triggers: ["taskCompleted"],
            steps: [
                ContentPackExperienceStep(
                    assetID: "enter",
                    role: .enter,
                    minimumPlaybackMs: 600,
                    transition: .crossfade
                ),
                ContentPackExperienceStep(
                    assetID: "react",
                    role: .react,
                    minimumPlaybackMs: nil,
                    transition: .cut
                )
            ],
            locales: ["en"],
            cooldownSeconds: 120,
            weight: 2,
            returnPolicy: .previousMode
        )
        let pack = makePack(
            packID: "cc.chengyin.pack.experience-v2",
            locales: ["en", "zh-Hans"],
            assets: assets,
            schemaVersion: 2,
            experiences: [experience]
        )
        let catalog = ContentPackRuntimeCatalog(activePacks: [pack])
        let selection = catalog.selectExperience(
            for: ["taskCompleted"],
            preferredLocale: "en-US",
            context: ContentPackSelectionContext(
                now: Date(timeIntervalSince1970: 2_000_000_000)
            ),
            randomSeed: 3
        )
        try require(selection?.sequence.kind == .ritual, "experience kind was lost")
        try require(
            selection?.sequence.videos.map(\.id).map { $0.split(separator: ":").last.map(String.init) } == ["enter", "react"],
            "experience step order was not preserved"
        )
        try require(
            selection?.sequence.returnPolicy == .previousMode,
            "experience return policy was lost"
        )
        try require(
            selection?.sequence.steps.map(\.role) == [.enter, .react],
            "experience step roles were lost"
        )
        try require(
            selection?.sequence.steps.map(\.transition) == [.crossfade, .cut],
            "experience transitions were lost"
        )
        try require(
            selection?.sequence.estimatedDuration == 10,
            "experience duration estimate was not derived from video metadata"
        )
        let sequenceID = selection?.sequence.id ?? ""
        let cooling = catalog.selectExperience(
            for: ["taskCompleted"],
            preferredLocale: "en-US",
            context: ContentPackSelectionContext(
                now: Date(timeIntervalSince1970: 2_000_000_030),
                lastPlayedAtByAssetID: [
                    sequenceID: Date(timeIntervalSince1970: 2_000_000_000)
                ]
            ),
            randomSeed: 3
        )
        try require(cooling == nil, "experience cooldown was ignored")
        try require(
            catalog.selectExperience(
                for: ["taskCompleted"],
                preferredLocale: "zh-Hans",
                randomSeed: 3
            ) == nil,
            "experience-level locale override was ignored"
        )
    }

    private static func sequenceCursorRejectsStaleCallbacks() throws {
        var cursor = CompanionSequencePlaybackCursor(
            sequenceID: "sequence-a",
            stepCount: 2
        )
        try require(
            cursor.stepEnded(sequenceID: "old-sequence", index: 0) == .ignored,
            "stale sequence callback was accepted"
        )
        try require(
            cursor.stepEnded(sequenceID: "sequence-a", index: 1) == .ignored,
            "out-of-order step callback was accepted"
        )
        try require(
            cursor.stepEnded(sequenceID: "sequence-a", index: 0) == .showStep(1),
            "first step did not advance"
        )
        try require(
            cursor.stepEnded(sequenceID: "sequence-a", index: 0) == .ignored,
            "duplicate step callback advanced twice"
        )
        try require(
            cursor.stepEnded(sequenceID: "sequence-a", index: 1) == .completed,
            "last step did not complete"
        )
        try require(
            cursor.stepEnded(sequenceID: "sequence-a", index: 1) == .ignored,
            "completed sequence accepted another callback"
        )
        cursor.reset(sequenceID: "sequence-b", stepCount: 1)
        try require(
            cursor.currentIndex == 0 && !cursor.isCompleted,
            "cursor reset did not start the replacement sequence"
        )
    }

    @MainActor
    private static func contentSequenceRuntimeOwnsReplacementAndCache() throws {
        enum Fallback: Equatable {
            case builtIn(String)
        }
        let firstCatalog = makeCatalog(
            packID: "cc.chengyin.pack.session-a",
            locales: ["en"],
            assets: [asset(id: "tap-a", trigger: "singleTap")]
        )
        let replacementCatalog = makeCatalog(
            packID: "cc.chengyin.pack.session-b",
            locales: ["en"],
            assets: [asset(id: "tap-b", trigger: "singleTap")]
        )
        let context = ContentPackSelectionContext(
            now: Date(timeIntervalSince1970: 2_000_000_000)
        )
        let runtime = CompanionContentSequenceRuntimeCoordinator<Fallback>()

        let cached = runtime.selectVideo(
            key: "tap",
            triggers: ["singleTap"],
            catalog: firstCatalog,
            preferredLocale: "en",
            context: context
        )
        let stillCached = runtime.selectVideo(
            key: "tap",
            triggers: ["singleTap"],
            catalog: replacementCatalog,
            preferredLocale: "en",
            context: context
        )
        try require(cached == stillCached, "same-key selection cache was not stable")
        runtime.resetSelectionCache()
        let refreshed = runtime.selectVideo(
            key: "tap",
            triggers: ["singleTap"],
            catalog: replacementCatalog,
            preferredLocale: "en",
            context: context
        )
        try require(
            refreshed?.id.hasPrefix("cc.chengyin.pack.session-b@") == true,
            "selection cache reset did not expose the replacement catalog"
        )

        let firstSequence = experienceCatalog(
            packID: "cc.chengyin.pack.sequence-a",
            experienceID: "first"
        )
        let replacementSequence = experienceCatalog(
            packID: "cc.chengyin.pack.sequence-b",
            experienceID: "second"
        )
        let first = runtime.selectAndBegin(
            triggers: ["taskCompleted"],
            catalog: firstSequence,
            preferredLocale: "en",
            context: context,
            fallback: .builtIn("first")
        )
        let replacement = runtime.selectAndBegin(
            triggers: ["taskCompleted"],
            catalog: replacementSequence,
            preferredLocale: "en",
            context: context,
            fallback: .builtIn("second")
        )
        try require(
            runtime.activeSequence?.id == replacement?.id,
            "replacement sequence did not become the single active session"
        )
        if case .ignored = runtime.finish(
            sequenceID: first?.id ?? "missing",
            succeeded: true
        ) {
            // Expected: a stale callback cannot finish the replacement.
        } else {
            throw DirectorSmokeFailure("stale sequence callback was accepted")
        }
        try require(
            runtime.activeSequence?.id == replacement?.id,
            "stale completion cleared the replacement sequence"
        )
        if case let .failed(fallback) = runtime.finish(
            sequenceID: replacement?.id ?? "missing",
            succeeded: false
        ) {
            try require(
                fallback == .builtIn("second"),
                "replacement fallback ownership was lost"
            )
        } else {
            throw DirectorSmokeFailure("active failure was not delivered once")
        }
        try require(!runtime.isActive, "terminal sequence remained active")
        if case .ignored = runtime.finish(
            sequenceID: replacement?.id ?? "missing",
            succeeded: false
        ) {
            // Expected: duplicate terminal callbacks are idempotent.
        } else {
            throw DirectorSmokeFailure("duplicate terminal callback was accepted")
        }
    }

    private static func experienceCatalog(
        packID: String,
        experienceID: String
    ) -> ContentPackRuntimeCatalog {
        let media = asset(id: "clip", trigger: "idle")
        let experience = ContentPackExperience(
            id: experienceID,
            kind: .ritual,
            triggers: ["taskCompleted"],
            steps: [
                ContentPackExperienceStep(
                    assetID: "clip",
                    role: .react,
                    minimumPlaybackMs: 500,
                    transition: .cut
                )
            ],
            locales: ["en"],
            cooldownSeconds: 0,
            weight: 1,
            returnPolicy: .previousMode
        )
        return ContentPackRuntimeCatalog(
            activePacks: [
                makePack(
                    packID: packID,
                    locales: ["en"],
                    assets: [media],
                    schemaVersion: 2,
                    experiences: [experience]
                )
            ]
        )
    }

    private static func makeCatalog(
        packID: String,
        locales: [String],
        assets: [ContentPackAsset]
    ) -> ContentPackRuntimeCatalog {
        ContentPackRuntimeCatalog(
            activePacks: [
                makePack(packID: packID, locales: locales, assets: assets)
            ]
        )
    }

    private static func makePack(
        packID: String,
        locales: [String],
        assets: [ContentPackAsset],
        schemaVersion: Int = 1,
        experiences: [ContentPackExperience]? = nil
    ) -> InstalledContentPack {
        let version = "1.0.0"
        return InstalledContentPack(
            record: ActiveContentPackRecord(
                packID: packID,
                version: version,
                previousVersion: nil,
                health: .healthy,
                activatedAt: Date(timeIntervalSince1970: 1_900_000_000)
            ),
            manifest: ContentPackManifest(
                schemaVersion: schemaVersion,
                id: packID,
                version: version,
                minAppVersion: "0.1.0",
                tier: .local,
                character: "chengyin",
                locales: locales,
                assets: assets,
                license: "Test-only",
                experiences: experiences
            ),
            directory: URL(fileURLWithPath: "/tmp/\(packID)", isDirectory: true)
        )
    }

    private static func asset(
        id: String,
        trigger: String,
        weight: Double = 1,
        cooldownSeconds: Int = 0
    ) -> ContentPackAsset {
        ContentPackAsset(
            id: id,
            kind: .video,
            path: "media/\(id).mov",
            sha256: String(repeating: "a", count: 64),
            durationMs: 5_000,
            width: 1_280,
            height: 720,
            aspectRatio: "16:9",
            hasNativeAudio: true,
            loop: false,
            cropAnchors: [
                "pet": .init(x: 0.5, y: 0.5, scale: 2.5),
                "partial": .init(x: 0.5, y: 0.5, scale: 1),
                "full": .init(x: 0.5, y: 0.5, scale: 1)
            ],
            triggers: [trigger],
            tags: ["director-smoke"],
            cooldownSeconds: cooldownSeconds,
            weight: weight
        )
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        if !condition() {
            throw DirectorSmokeFailure(message)
        }
    }
}

private struct DirectorSmokeFailure: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
