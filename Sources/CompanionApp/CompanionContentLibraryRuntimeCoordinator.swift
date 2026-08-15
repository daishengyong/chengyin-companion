import Combine
import Foundation

struct CompanionContentPlaybackValidation: Equatable, Sendable {
    fileprivate let key: String
    fileprivate let generation: UInt64
}

/// Owns the user-visible projection and asynchronous health-validation
/// lifetimes for the local content library.
///
/// The actor-backed store remains the disk authority. This MainActor object
/// holds only its latest immutable inventory, derived catalog/summary state,
/// and opaque per-version validation generations. A stale recovery or playback
/// callback therefore cannot overwrite a newer install, rollback or retry.
@MainActor
final class CompanionContentLibraryRuntimeCoordinator: ObservableObject {
    @Published private(set) var enabledPackCount = 0
    @Published private(set) var health = CompanionLocalization.string(
        key: "pack.health.unchecked",
        fallback: "内容包尚未检查"
    )
    @Published private(set) var qualitySummary = "Lab 0 · Stable 0 · Verified 0"
    @Published private(set) var summaries: [CompanionContentPackSummary] = []
    @Published private(set) var catalog = ContentPackRuntimeCatalog.empty

    private(set) var inventory: [InstalledContentPack] = []
    private var recoveryTask: Task<Void, Never>?
    private var recoveryGeneration: UInt64 = 0
    private var playbackGeneration: UInt64 = 0
    private var playbackValidations: [String: UInt64] = [:]

    deinit {
        recoveryTask?.cancel()
    }

    func setEnabled(_ enabled: Bool) {
        cancelRecovery()
        playbackGeneration &+= 1
        playbackValidations.removeAll()
        projectInventory(enabled: enabled)
        health = enabled
            ? Self.text("pack.global.enabled", "本地内容包已恢复")
            : Self.text(
                "pack.global.safeMode",
                "Starter 自救模式：本地内容包已暂停"
            )
    }

    func replaceInventory(
        _ inventory: [InstalledContentPack],
        enabled: Bool
    ) {
        cancelRecovery()
        applyInventory(inventory, enabled: enabled)
    }

    private func applyInventory(
        _ inventory: [InstalledContentPack],
        enabled: Bool
    ) {
        self.inventory = inventory
        let pendingKeys = Set(inventory.compactMap { pack in
            pack.record.health == .pendingHealth
                ? Self.key(pack.record.packID, pack.record.version)
                : nil
        })
        playbackValidations = playbackValidations.filter { pendingKeys.contains($0.key) }
        projectInventory(enabled: enabled)
    }

    func setHealth(_ message: String, enabled: Bool) {
        health = enabled
            ? message
            : Self.text(
                "pack.global.safeMode",
                "Starter 自救模式：本地内容包已暂停"
            )
    }

    func invalidatePlaybackValidation(
        packID: String,
        version: String
    ) {
        playbackValidations.removeValue(forKey: Self.key(packID, version))
    }

    func beginPlaybackValidation(
        _ reference: ContentPackPlaybackReference
    ) -> CompanionContentPlaybackValidation? {
        guard reference.health == .pendingHealth else { return nil }
        let key = Self.key(reference.packID, reference.version)
        guard playbackValidations[key] == nil else { return nil }
        playbackGeneration &+= 1
        playbackValidations[key] = playbackGeneration
        return CompanionContentPlaybackValidation(
            key: key,
            generation: playbackGeneration
        )
    }

    @discardableResult
    func completePlaybackValidation(
        _ validation: CompanionContentPlaybackValidation,
        inventory: [InstalledContentPack],
        succeeded: Bool,
        enabled: Bool
    ) -> Bool {
        guard playbackValidations[validation.key] == validation.generation else {
            return false
        }
        playbackValidations.removeValue(forKey: validation.key)
        replaceInventory(inventory, enabled: enabled)
        setHealth(
            succeeded
                ? Self.text(
                    "pack.health.firstPlaybackPassed",
                    "内容包首播通过，已标记健康"
                )
                : Self.text(
                    "pack.health.firstPlaybackFailed",
                    "内容包首播失败，已安全回退"
                ),
            enabled: enabled
        )
        return true
    }

    @discardableResult
    func failPlaybackValidation(
        _ validation: CompanionContentPlaybackValidation,
        enabled: Bool
    ) -> Bool {
        guard playbackValidations[validation.key] == validation.generation else {
            return false
        }
        playbackValidations.removeValue(forKey: validation.key)
        setHealth(
            Self.text(
                "pack.health.playbackNeedsRepair",
                "内容包播放健康检查需要修复"
            ),
            enabled: enabled
        )
        return true
    }

    func startRecovery(
        enabled: @escaping @MainActor () -> Bool,
        recover: @escaping @MainActor () async throws -> CompanionContentRecoveryReceipt,
        onLibraryHealthChanged: @escaping @MainActor (Bool) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        cancelRecovery()
        let generation = recoveryGeneration
        recoveryTask = Task { [weak self] in
            guard let self else { return }
            do {
                let receipt = try await recover()
                guard !Task.isCancelled,
                      recoveryGeneration == generation else { return }
                onLibraryHealthChanged(true)
                applyInventory(receipt.inventory, enabled: enabled())
                setHealth(
                    receipt.cleaned > 0
                        ? Self.format(
                            "pack.health.recovered",
                            "内容包正常，已清理 %d 个中断安装",
                            receipt.cleaned
                        )
                        : Self.text("pack.health.normal", "内容包正常"),
                    enabled: enabled()
                )
                recoveryTask = nil
            } catch {
                guard !Task.isCancelled,
                      recoveryGeneration == generation else { return }
                onLibraryHealthChanged(false)
                setHealth(
                    Self.text("pack.health.needsRepair", "内容包需要修复"),
                    enabled: enabled()
                )
                onFailure(error)
                recoveryTask = nil
            }
        }
    }

    func cancelRecovery() {
        recoveryGeneration &+= 1
        recoveryTask?.cancel()
        recoveryTask = nil
    }

    private func projectInventory(enabled: Bool) {
        let active = inventory.filter { $0.record.health != .disabled }
        enabledPackCount = enabled ? active.count : 0
        let qualityCounts = Dictionary(
            grouping: active,
            by: \.qualityLevel
        ).mapValues(\.count)
        qualitySummary = [
            "Lab \(qualityCounts[.lab, default: 0])",
            "Stable \(qualityCounts[.stable, default: 0])",
            "Verified \(qualityCounts[.verified, default: 0])"
        ].joined(separator: " · ")
        summaries = inventory.map { pack in
            CompanionContentPackSummary(
                packID: pack.record.packID,
                version: pack.record.version,
                character: pack.manifest.character,
                locales: pack.manifest.locales,
                qualityLevel: pack.qualityLevel,
                health: pack.record.health,
                canRollback: pack.record.previousVersion != nil,
                contributionReady: pack.manifest.contributionReadiness.isReady,
                contributionMode: pack.manifest.contributionMode
            )
        }
        catalog = ContentPackRuntimeCatalog(
            activePacks: enabled ? active : []
        )
    }

    private static func key(_ packID: String, _ version: String) -> String {
        "\(packID)@\(version)"
    }

    private static func text(_ key: String, _ fallback: String) -> String {
        CompanionLocalization.string(key: key, fallback: fallback)
    }

    private static func format(
        _ key: String,
        _ fallback: String,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: text(key, fallback),
            locale: Locale.current,
            arguments: arguments
        )
    }
}
