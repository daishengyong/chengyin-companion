#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Combine
import Foundation

/// Focused MainActor boundary for portable backup export, preflight and
/// confirmed restore. Security-scoped access and pending-preview ownership do
/// not leak into the broader content-pack transaction coordinator.
@MainActor
final class CompanionBackupOperationsCoordinator: ObservableObject {
    @Published private(set) var operationInProgress = false
    @Published private(set) var operationMessage: String?
    @Published private(set) var pendingPreview: CompanionBackupPreview?

    private let library: CompanionContentLibrary

    init(library: CompanionContentLibrary) {
        self.library = library
    }

    func exportBackup(
        to destination: URL,
        settings: CompanionSettingsV1
    ) async -> CompanionContentOperationReceipt? {
        guard begin(
            message: text(
                "backup.operation.exporting",
                "正在导出设置与活动内容包…"
            )
        ) else { return nil }
        let parent = destination.deletingLastPathComponent()
        let accessing = parent.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                parent.stopAccessingSecurityScopedResource()
            }
            operationInProgress = false
        }
        do {
            let manifest = try await library.exportBackup(
                to: destination,
                settings: settings
            )
            operationMessage = String(
                format: text(
                    "backup.operation.exported",
                    "备份已导出：%d 个内容包。"
                ),
                manifest.packs.count
            )
            return CompanionContentOperationReceiptFactory.success(
                operation: .exportBackup,
                value: .backupExported(packCount: manifest.packs.count)
            )
        } catch {
            return failure(.exportBackup, error)
        }
    }

    func inspectBackup(
        at directory: URL
    ) async -> CompanionContentOperationReceipt? {
        guard begin(
            message: text("backup.operation.inspecting", "正在检查备份…")
        ) else { return nil }
        let accessing = directory.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                directory.stopAccessingSecurityScopedResource()
            }
            operationInProgress = false
        }
        do {
            let manifest = try await library.inspectBackup(at: directory)
            let preview = CompanionBackupPreview(
                directory: directory,
                createdAt: manifest.createdAt,
                appVersion: manifest.appVersion,
                packCount: manifest.packs.count
            )
            pendingPreview = preview
            operationMessage = text(
                "backup.operation.inspected",
                "备份检查通过，确认后才会恢复。"
            )
            return CompanionContentOperationReceiptFactory.success(
                operation: .inspectBackup,
                value: .backupInspected(preview: preview)
            )
        } catch {
            pendingPreview = nil
            return failure(.inspectBackup, error)
        }
    }

    func cancelRestore() {
        pendingPreview = nil
    }

    func presentRestoreCompletion(
        installedPackCount: Int,
        repairCount: Int
    ) {
        if repairCount > 0 {
            operationMessage = String(
                format: text(
                    "backup.operation.restoredWithAdjustments",
                    "恢复完成：%d 个内容包，%d 项不兼容设置已安全调整。"
                ),
                installedPackCount,
                repairCount
            )
        } else {
            operationMessage = String(
                format: text(
                    "backup.operation.restored",
                    "恢复完成：%d 个内容包，偏好设置已应用。"
                ),
                installedPackCount
            )
        }
    }

    func restoreInspectedBackup() async -> CompanionContentOperationReceipt? {
        guard !operationInProgress,
              let preview = pendingPreview
        else { return nil }
        operationInProgress = true
        operationMessage = text(
            "backup.operation.restoring",
            "正在恢复设置与内容包…"
        )
        let accessing = preview.directory.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                preview.directory.stopAccessingSecurityScopedResource()
            }
            operationInProgress = false
        }
        do {
            let snapshot = try await library.restoreBackup(
                from: preview.directory
            )
            pendingPreview = nil
            operationMessage = String(
                format: text(
                    "backup.operation.restored",
                    "恢复完成：%d 个内容包，偏好设置已应用。"
                ),
                snapshot.result.installedPacks.count
            )
            return CompanionContentOperationReceiptFactory.success(
                operation: .restoreBackup,
                value: .backupRestored(
                    settings: snapshot.result.settings,
                    installedPackCount: snapshot.result.installedPacks.count,
                    inventory: snapshot.inventory
                )
            )
        } catch {
            return failure(.restoreBackup, error)
        }
    }

    private func begin(message: String) -> Bool {
        guard !operationInProgress else { return false }
        operationInProgress = true
        operationMessage = message
        return true
    }

    private func failure(
        _ operation: CompanionContentOperationKind,
        _ error: Error
    ) -> CompanionContentOperationReceipt {
        let result = CompanionContentOperationReceiptFactory.failure(
            operation: operation,
            error: error
        )
        operationMessage = result.presentationMessage
        return result.receipt
    }

    private func text(_ key: String, _ fallback: String) -> String {
        CompanionLocalization.string(key: key, fallback: fallback)
    }
}
