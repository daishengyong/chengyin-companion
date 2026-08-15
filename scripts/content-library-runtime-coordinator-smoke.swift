import Foundation

enum ContentPackHealthStatus: String, Equatable, Sendable {
    case pendingHealth
    case healthy
    case disabled
}

enum ContentPackQualityLevel: String, Equatable, Sendable {
    case lab
    case stable
    case verified
}

enum ContentPackContributionMode: String, Equatable, Sendable {
    case legacyV1
    case compatibilityV2
    case strictV2
}

struct ContentPackContributionReadiness: Equatable, Sendable {
    let isReady: Bool
}

struct ActiveContentPackRecord: Equatable, Sendable {
    let packID: String
    let version: String
    let previousVersion: String?
    let health: ContentPackHealthStatus
}

struct ContentPackManifest: Equatable, Sendable {
    let character: String
    let locales: [String]
    let contributionReadiness: ContentPackContributionReadiness
    let contributionMode: ContentPackContributionMode
    let tierVerified: Bool
}

struct InstalledContentPack: Equatable, Sendable {
    let record: ActiveContentPackRecord
    let manifest: ContentPackManifest

    var qualityLevel: ContentPackQualityLevel {
        guard record.health == .healthy else { return .lab }
        return manifest.tierVerified ? .verified : .stable
    }
}

struct CompanionContentPackSummary: Identifiable, Equatable, Sendable {
    let packID: String
    let version: String
    let character: String
    let locales: [String]
    let qualityLevel: ContentPackQualityLevel
    let health: ContentPackHealthStatus
    let canRollback: Bool
    let contributionReady: Bool
    let contributionMode: ContentPackContributionMode
    var id: String { packID }
}

struct ContentPackRuntimeCatalog: Equatable, Sendable {
    static let empty = ContentPackRuntimeCatalog(activePacks: [])
    let packIDs: [String]

    init(activePacks: [InstalledContentPack]) {
        packIDs = activePacks.map(\.record.packID).sorted()
    }
}

struct ContentPackPlaybackReference: Equatable, Sendable {
    let packID: String
    let version: String
    let health: ContentPackHealthStatus
}

struct CompanionContentRecoveryReceipt: Equatable, Sendable {
    let cleaned: Int
    let inventory: [InstalledContentPack]
    let recovery: [String]
}

@main
enum ContentLibraryRuntimeCoordinatorSmoke {
    @MainActor
    static func main() async throws {
        let runtime = CompanionContentLibraryRuntimeCoordinator()
        try require(runtime.enabledPackCount == 0, "Initial enabled count was not empty")
        try require(runtime.catalog == .empty, "Initial runtime catalog was not empty")

        let pending = pack(
            id: "local.pending",
            version: "1.0.0",
            health: .pendingHealth,
            contributionReady: false
        )
        let stable = pack(
            id: "local.stable",
            version: "2.0.0",
            previousVersion: "1.0.0",
            health: .healthy,
            contributionReady: true
        )
        let disabled = pack(
            id: "local.disabled",
            version: "1.0.0",
            health: .disabled,
            contributionReady: false
        )
        runtime.replaceInventory([pending, stable, disabled], enabled: true)
        try require(runtime.enabledPackCount == 2, "Disabled pack counted as enabled")
        try require(runtime.summaries.count == 3, "Inventory summary lost disabled pack")
        try require(
            runtime.qualitySummary == "Lab 1 · Stable 1 · Verified 0",
            "Derived quality summary was incorrect"
        )
        try require(
            runtime.catalog.packIDs == ["local.pending", "local.stable"],
            "Runtime catalog did not exclude the disabled pack"
        )

        runtime.setEnabled(false)
        try require(runtime.enabledPackCount == 0, "Safe mode kept packs enabled")
        try require(runtime.catalog == .empty, "Safe mode retained runtime media")
        try require(runtime.summaries.count == 3, "Safe mode deleted inventory projection")
        try require(
            runtime.health.contains("Starter"),
            "Safe mode lost its user-visible fallback state"
        )
        runtime.setEnabled(true)
        try require(runtime.enabledPackCount == 2, "Re-enable did not restore inventory")

        let reference = ContentPackPlaybackReference(
            packID: pending.record.packID,
            version: pending.record.version,
            health: .pendingHealth
        )
        guard let first = runtime.beginPlaybackValidation(reference) else {
            throw Failure("Pending playback did not start validation")
        }
        try require(
            runtime.beginPlaybackValidation(reference) == nil,
            "Duplicate playback validation was accepted"
        )
        runtime.setEnabled(false)
        try require(
            !runtime.completePlaybackValidation(
                first,
                inventory: [stable],
                succeeded: true,
                enabled: false
            ),
            "Safe-mode change accepted an older playback validation"
        )
        runtime.setEnabled(true)
        guard let afterSafeMode = runtime.beginPlaybackValidation(reference) else {
            throw Failure("Safe-mode exit did not permit a fresh playback validation")
        }
        runtime.invalidatePlaybackValidation(
            packID: reference.packID,
            version: reference.version
        )
        guard let retry = runtime.beginPlaybackValidation(reference) else {
            throw Failure("Explicit retry did not reopen playback validation")
        }
        try require(
            !runtime.completePlaybackValidation(
                afterSafeMode,
                inventory: [stable],
                succeeded: true,
                enabled: true
            ),
            "Stale playback success overwrote a newer retry"
        )
        try require(
            runtime.failPlaybackValidation(retry, enabled: true),
            "Current playback failure was not accepted"
        )
        guard let final = runtime.beginPlaybackValidation(reference) else {
            throw Failure("Failure did not permit a bounded retry")
        }
        let promoted = pack(
            id: reference.packID,
            version: reference.version,
            health: .healthy,
            contributionReady: false
        )
        try require(
            runtime.completePlaybackValidation(
                final,
                inventory: [promoted, stable],
                succeeded: true,
                enabled: true
            ),
            "Current playback success was not committed"
        )
        try require(runtime.enabledPackCount == 2, "Promoted inventory was not projected")
        try require(
            runtime.health.contains("首播通过"),
            "Playback success lost its localized health state"
        )

        let oldRecovery = RecoveryGate()
        var oldHealthCallbacks: [Bool] = []
        var oldFailureCount = 0
        runtime.startRecovery(
            enabled: { true },
            recover: { try await oldRecovery.wait() },
            onLibraryHealthChanged: { oldHealthCallbacks.append($0) },
            onFailure: { _ in oldFailureCount += 1 }
        )
        await Task.yield()
        runtime.replaceInventory([stable], enabled: true)
        oldRecovery.resume(
            CompanionContentRecoveryReceipt(
                cleaned: 9,
                inventory: [pending],
                recovery: []
            )
        )
        await settle()
        try require(
            runtime.catalog.packIDs == ["local.stable"],
            "Cancelled recovery overwrote a newer inventory"
        )
        try require(
            oldHealthCallbacks.isEmpty && oldFailureCount == 0,
            "Cancelled recovery emitted a stale terminal callback"
        )

        let safeModeRecovery = RecoveryGate()
        var safeModeCallbacks: [Bool] = []
        runtime.startRecovery(
            enabled: { true },
            recover: { try await safeModeRecovery.wait() },
            onLibraryHealthChanged: { safeModeCallbacks.append($0) },
            onFailure: { _ in throwAway() }
        )
        await Task.yield()
        runtime.setEnabled(false)
        safeModeRecovery.resume(
            CompanionContentRecoveryReceipt(
                cleaned: 4,
                inventory: [pending],
                recovery: []
            )
        )
        await settle()
        try require(
            safeModeCallbacks.isEmpty,
            "Safe-mode change accepted an older recovery callback"
        )
        try require(runtime.catalog == .empty, "Safe mode republished recovered media")
        runtime.setEnabled(true)
        try require(
            runtime.catalog.packIDs == ["local.stable"],
            "Safe-mode cancellation replaced the retained inventory"
        )

        let currentRecovery = RecoveryGate()
        var healthCallbacks: [Bool] = []
        runtime.startRecovery(
            enabled: { true },
            recover: { try await currentRecovery.wait() },
            onLibraryHealthChanged: { healthCallbacks.append($0) },
            onFailure: { _ in throwAway() }
        )
        await Task.yield()
        currentRecovery.resume(
            CompanionContentRecoveryReceipt(
                cleaned: 2,
                inventory: [pending, stable],
                recovery: []
            )
        )
        await settle()
        try require(healthCallbacks == [true], "Current recovery did not report health")
        try require(runtime.enabledPackCount == 2, "Current recovery was not projected")
        try require(runtime.health.contains("2"), "Recovery cleanup count was not presented")

        var failureCallbacks: [Bool] = []
        var failureCount = 0
        runtime.startRecovery(
            enabled: { true },
            recover: { throw Failure("fixture") },
            onLibraryHealthChanged: { failureCallbacks.append($0) },
            onFailure: { _ in failureCount += 1 }
        )
        await settle()
        try require(failureCallbacks == [false], "Recovery failure did not mark unhealthy")
        try require(failureCount == 1, "Recovery failure callback count was not bounded")
        try require(runtime.health.contains("需要修复"), "Recovery failure lost safe health copy")

        print(
            "Content library runtime coordinator smoke: PASS "
            + "(projection, safe mode, stale playback and recovery rejection)"
        )
    }

    private static func pack(
        id: String,
        version: String,
        previousVersion: String? = nil,
        health: ContentPackHealthStatus,
        contributionReady: Bool
    ) -> InstalledContentPack {
        InstalledContentPack(
            record: ActiveContentPackRecord(
                packID: id,
                version: version,
                previousVersion: previousVersion,
                health: health
            ),
            manifest: ContentPackManifest(
                character: id,
                locales: ["zh-Hans", "en-US"],
                contributionReadiness: ContentPackContributionReadiness(
                    isReady: contributionReady
                ),
                contributionMode: contributionReady ? .strictV2 : .compatibilityV2,
                tierVerified: false
            )
        )
    }

    private static func settle() async {
        for _ in 0..<8 { await Task.yield() }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else { throw Failure(message) }
    }

    private static func throwAway() {}
}

@MainActor
private final class RecoveryGate {
    private var continuation: CheckedContinuation<CompanionContentRecoveryReceipt, Error>?

    func wait() async throws -> CompanionContentRecoveryReceipt {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func resume(_ receipt: CompanionContentRecoveryReceipt) {
        continuation?.resume(returning: receipt)
        continuation = nil
    }
}

private struct Failure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
