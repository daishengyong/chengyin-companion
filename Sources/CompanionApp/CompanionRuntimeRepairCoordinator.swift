import Combine
import CompanionContracts
import Foundation

/// Owns the bounded runtime-health refresh and repair lifecycle.
///
/// This coordinator may ask the two focused local coordinators to repair the
/// event bridge or recover interrupted content transactions. It never replaces
/// the app, deletes media, changes preferences, opens a network connection or
/// hides attention states that still need manual review.
@MainActor
final class CompanionRuntimeRepairCoordinator: ObservableObject {
    @Published private(set) var snapshot = CompanionRuntimeSupportSnapshot.empty
    @Published private(set) var isRepairing = false
    @Published private(set) var message: String?

    private var contentLibraryHealthy = true
    private var operationTask: Task<Void, Never>?

    func markContentLibraryHealthy(_ healthy: Bool) {
        contentLibraryHealthy = healthy
    }

    func rebuild(
        voiceFileNames: [String],
        eventBridgeReady: Bool,
        localContentPacksEnabled: Bool
    ) {
        snapshot = CompanionRuntimeSupport.collect(
            voiceFileNames: voiceFileNames,
            eventBridgeReady: eventBridgeReady,
            localContentPacksEnabled: localContentPacksEnabled,
            contentLibraryHealthy: contentLibraryHealthy
        )
    }

    func refresh(
        workdayRuntime: CompanionWorkdayRuntimeCoordinator,
        voiceFileNames: [String],
        localContentPacksEnabled: Bool
    ) {
        guard !isRepairing else { return }
        operationTask?.cancel()
        operationTask = Task { [weak self, weak workdayRuntime] in
            guard let self, let workdayRuntime else { return }
            _ = await workdayRuntime.refreshEventBridgeReadiness()
            guard !Task.isCancelled else { return }
            rebuild(
                voiceFileNames: voiceFileNames,
                eventBridgeReady: workdayRuntime.eventBridgeReady,
                localContentPacksEnabled: localContentPacksEnabled
            )
        }
    }

    func repair(
        workdayRuntime: CompanionWorkdayRuntimeCoordinator,
        contentOperations: CompanionContentOperationsCoordinator,
        voiceFileNames: [String],
        localContentPacksEnabled: Bool,
        applyInventory: @escaping @MainActor ([InstalledContentPack]) -> Void,
        setContentHealth: @escaping @MainActor (String) -> Void
    ) {
        guard !isRepairing else { return }
        let actions = snapshot.safeRecoveryActions
        guard !actions.isEmpty else {
            refresh(
                workdayRuntime: workdayRuntime,
                voiceFileNames: voiceFileNames,
                localContentPacksEnabled: localContentPacksEnabled
            )
            return
        }

        operationTask?.cancel()
        isRepairing = true
        message = nil
        operationTask = Task {
            var failureCodes: [String] = []

            if actions.contains(.repairEventBridge) {
                let receipt = await workdayRuntime.repairEventBridge()
                if !receipt.isReady {
                    failureCodes.append(
                        receipt.code ?? "UI_RUNTIME_REPAIR_FAILED"
                    )
                }
            }

            if !Task.isCancelled,
               actions.contains(.recoverContentLibrary) {
                do {
                    let recovery = try await contentOperations
                        .recoverInterruptedInstalls()
                    contentLibraryHealthy = true
                    applyInventory(recovery.inventory)
                    setContentHealth(
                        recovery.cleaned > 0
                            ? Self.format(
                                "pack.health.recovered",
                                "内容包正常，已清理 %d 个中断安装",
                                recovery.cleaned
                            )
                            : Self.text("pack.health.normal", "内容包正常")
                    )
                } catch {
                    contentLibraryHealthy = false
                    failureCodes.append("UI_RUNTIME_REPAIR_FAILED")
                }
            }

            guard !Task.isCancelled else {
                isRepairing = false
                return
            }
            _ = await workdayRuntime.refreshEventBridgeReadiness()
            rebuild(
                voiceFileNames: voiceFileNames,
                eventBridgeReady: workdayRuntime.eventBridgeReady,
                localContentPacksEnabled: localContentPacksEnabled
            )
            isRepairing = false

            if !failureCodes.isEmpty {
                let codes = Array(Set(failureCodes))
                    .sorted()
                    .joined(separator: ", ")
                message = Self.format(
                    "readiness.repair.incomplete",
                    "安全修复未完成（%@）。异常文件未被替换；请复制隐私最小诊断继续检查。",
                    codes
                )
            } else if snapshot.hasManualAttention {
                message = Self.text(
                    "readiness.repair.manualRemaining",
                    "可安全修复的项目已恢复；其余项目需要人工检查，未被自动改写。"
                )
            } else {
                message = Self.text(
                    "readiness.repair.complete",
                    "本机安全修复完成，内容和偏好均已保留。"
                )
            }
        }
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
            format: CompanionLocalization.string(key: key, fallback: fallback),
            locale: Locale.current,
            arguments: arguments
        )
    }
}
