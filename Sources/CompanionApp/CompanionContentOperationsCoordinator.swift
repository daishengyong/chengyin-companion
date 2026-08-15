#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Combine
import Foundation

/// One MainActor boundary for creator-facing content transactions. It owns
/// progress, security-scoped access, recoverable removal state and path-safe
/// error presentation; the view model applies only successful inventory and
/// settings projections to the rest of the experience.
@MainActor
final class CompanionContentOperationsCoordinator: ObservableObject {
    @Published private(set) var contentPackOperationInProgress = false
    @Published private(set) var contentPackOperationMessage: String?
    @Published private(set) var contentPackUndoRemovalAvailable = false
    @Published private(set) var contentPackRecoveryItems: [ContentPackRecoveryItem] = []

    private let library: CompanionContentLibrary
    private let backupOperations: CompanionBackupOperationsCoordinator
    private var lastRemovalReceipt: ContentPackRemovalReceipt?
    private var backupObservation: AnyCancellable?

    var backupOperationInProgress: Bool {
        backupOperations.operationInProgress
    }

    var backupOperationMessage: String? {
        backupOperations.operationMessage
    }

    var pendingBackupPreview: CompanionBackupPreview? {
        backupOperations.pendingPreview
    }

    func presentBackupRestoreCompletion(
        installedPackCount: Int,
        repairCount: Int
    ) {
        backupOperations.presentRestoreCompletion(
            installedPackCount: installedPackCount,
            repairCount: repairCount
        )
    }

    convenience init(root: URL, currentAppVersion: String) {
        self.init(
            library: CompanionContentLibrary(
                root: root,
                currentAppVersion: currentAppVersion
            )
        )
    }

    init(library: CompanionContentLibrary) {
        self.library = library
        let backupOperations = CompanionBackupOperationsCoordinator(
            library: library
        )
        self.backupOperations = backupOperations
        backupObservation = backupOperations.objectWillChange.sink {
            [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func install(from source: URL) async -> CompanionContentOperationReceipt? {
        guard beginPackOperation(
            message: text(
                "pack.operation.validating",
                "正在验证并安装本地内容包…"
            )
        ) else { return nil }
        let accessing = source.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                source.stopAccessingSecurityScopedResource()
            }
            contentPackOperationInProgress = false
        }
        do {
            let snapshot = try await library.install(from: source)
            let result = snapshot.result
            let format = text(
                result.disposition == .installed
                    ? "pack.operation.installed"
                    : "pack.operation.reused",
                result.disposition == .installed
                    ? "已安全安装 %@ %@。"
                    : "%@ %@ 已存在，已重新启用。"
            )
            contentPackOperationMessage = String(
                format: format,
                result.pack.manifest.character,
                result.pack.record.version
            )
            return success(
                .install,
                .installed(result: result, inventory: snapshot.inventory)
            )
        } catch {
            return failure(.install, error)
        }
    }

    func rollback(packID: String) async -> CompanionContentOperationReceipt? {
        guard beginPackOperation(
            message: text("pack.operation.rollingBack", "正在回滚内容包…")
        ) else { return nil }
        defer { contentPackOperationInProgress = false }
        do {
            let snapshot = try await library.rollback(packID: packID)
            contentPackOperationMessage = String(
                format: text(
                    "pack.operation.rolledBack",
                    "已回滚到 %@ %@。"
                ),
                snapshot.pack.manifest.character,
                snapshot.pack.record.version
            )
            return success(
                .rollback,
                .rolledBack(
                    pack: snapshot.pack,
                    inventory: snapshot.inventory
                )
            )
        } catch {
            return failure(.rollback, error)
        }
    }

    func remove(packID: String) async -> CompanionContentOperationReceipt? {
        guard beginPackOperation(
            message: text("pack.operation.removing", "正在停用并移出内容包…")
        ) else { return nil }
        defer { contentPackOperationInProgress = false }
        do {
            let snapshot = try await library.remove(packID: packID)
            lastRemovalReceipt = snapshot.receipt
            contentPackUndoRemovalAvailable = true
            contentPackRecoveryItems = snapshot.recovery
            contentPackOperationMessage = text(
                "pack.operation.removed",
                "内容包已移到本地恢复区，可以立即撤销。"
            )
            return success(
                .remove,
                .removed(
                    inventory: snapshot.inventory,
                    recovery: snapshot.recovery
                )
            )
        } catch {
            return failure(.remove, error)
        }
    }

    func restoreLastRemoval() async -> CompanionContentOperationReceipt? {
        guard !contentPackOperationInProgress,
              let receipt = lastRemovalReceipt
        else { return nil }
        contentPackOperationInProgress = true
        contentPackOperationMessage = text(
            "pack.operation.restoring",
            "正在恢复内容包…"
        )
        defer { contentPackOperationInProgress = false }
        do {
            let snapshot = try await library.restoreRemoval(receipt)
            lastRemovalReceipt = nil
            contentPackUndoRemovalAvailable = false
            contentPackRecoveryItems = snapshot.recovery
            contentPackOperationMessage = String(
                format: text(
                    "pack.operation.restored",
                    "已恢复 %@ %@。"
                ),
                snapshot.pack.manifest.character,
                snapshot.pack.record.version
            )
            return success(
                .restoreRemoval,
                .removalRestored(
                    pack: snapshot.pack,
                    inventory: snapshot.inventory,
                    recovery: snapshot.recovery
                )
            )
        } catch {
            return failure(.restoreRemoval, error)
        }
    }

    func restoreRecoveryItem(id: String) async -> CompanionContentOperationReceipt? {
        guard beginPackOperation(
            message: text("pack.operation.restoring", "正在恢复内容包…")
        ) else { return nil }
        defer { contentPackOperationInProgress = false }
        do {
            let snapshot = try await library.restoreRecoveryItem(id: id)
            contentPackRecoveryItems = snapshot.recovery
            contentPackOperationMessage = String(
                format: text("pack.operation.restored", "已恢复 %@ %@。"),
                snapshot.pack.manifest.character,
                snapshot.pack.record.version
            )
            return success(
                .restoreRemoval,
                .removalRestored(
                    pack: snapshot.pack,
                    inventory: snapshot.inventory,
                    recovery: snapshot.recovery
                )
            )
        } catch {
            return failure(.restoreRemoval, error)
        }
    }

    func purgeRecoveryItem(id: String) async -> CompanionContentOperationReceipt? {
        guard beginPackOperation(
            message: text("pack.operation.purging", "正在永久清理恢复项…")
        ) else { return nil }
        defer { contentPackOperationInProgress = false }
        do {
            let snapshot = try await library.purgeRecoveryItem(id: id)
            contentPackRecoveryItems = snapshot.recovery
            contentPackOperationMessage = text(
                "pack.operation.purged",
                "恢复项已从本机永久清理。"
            )
            return success(
                .purgeRecovery,
                .recoveryPurged(
                    inventory: snapshot.inventory,
                    recovery: snapshot.recovery
                )
            )
        } catch {
            return failure(.purgeRecovery, error)
        }
    }

    func exportBackup(
        to destination: URL,
        settings: CompanionSettingsV1
    ) async -> CompanionContentOperationReceipt? {
        await backupOperations.exportBackup(
            to: destination,
            settings: settings
        )
    }

    func inspectBackup(
        at directory: URL
    ) async -> CompanionContentOperationReceipt? {
        await backupOperations.inspectBackup(at: directory)
    }

    func cancelBackupRestore() {
        backupOperations.cancelRestore()
    }

    func restoreInspectedBackup() async -> CompanionContentOperationReceipt? {
        await backupOperations.restoreInspectedBackup()
    }

    func recoverInterruptedInstalls() async throws -> CompanionContentRecoveryReceipt {
        let recovery = try await library.recoverInterruptedInstalls()
        contentPackRecoveryItems = recovery.recovery
        return CompanionContentRecoveryReceipt(
            cleaned: recovery.cleaned,
            inventory: recovery.inventory,
            recovery: recovery.recovery
        )
    }

    func reportPlayback(
        reference: ContentPackPlaybackReference,
        succeeded: Bool
    ) async throws -> [InstalledContentPack] {
        try await library.reportPlayback(
            reference: reference,
            succeeded: succeeded
        )
    }

    private func beginPackOperation(message: String) -> Bool {
        guard !contentPackOperationInProgress else { return false }
        contentPackOperationInProgress = true
        contentPackOperationMessage = message
        return true
    }

    private func success(
        _ operation: CompanionContentOperationKind,
        _ success: CompanionContentOperationSuccess
    ) -> CompanionContentOperationReceipt {
        CompanionContentOperationReceiptFactory.success(
            operation: operation,
            value: success
        )
    }

    private func failure(
        _ operation: CompanionContentOperationKind,
        _ error: Error
    ) -> CompanionContentOperationReceipt {
        let result = CompanionContentOperationReceiptFactory.failure(
            operation: operation,
            error: error
        )
        contentPackOperationMessage = result.presentationMessage
        return result.receipt
    }

    private func text(_ key: String, _ fallback: String) -> String {
        CompanionLocalization.string(key: key, fallback: fallback)
    }
}
