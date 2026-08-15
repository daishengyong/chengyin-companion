#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Foundation

struct CompanionContentOperationFailureResult {
    let presentationMessage: String
    let receipt: CompanionContentOperationReceipt
}

/// Pure path-safe receipt and localized failure projection shared by content
/// and backup coordinators. It owns no progress state, filesystem access or
/// recovery lifecycle.
enum CompanionContentOperationReceiptFactory {
    static func success(
        operation: CompanionContentOperationKind,
        value: CompanionContentOperationSuccess
    ) -> CompanionContentOperationReceipt {
        CompanionContentOperationReceipt(
            operation: operation,
            success: value,
            presentedError: nil
        )
    }

    static func failure(
        operation: CompanionContentOperationKind,
        error: Error
    ) -> CompanionContentOperationFailureResult {
        let presented = CompanionErrorPresentation.message(for: error)
        return CompanionContentOperationFailureResult(
            presentationMessage: presented,
            receipt: CompanionContentOperationReceipt(
                operation: operation,
                success: nil,
                presentedError: contextualError(
                    for: operation,
                    presentedError: presented
                )
            )
        )
    }

    private static func contextualError(
        for operation: CompanionContentOperationKind,
        presentedError: String
    ) -> String {
        let key: String
        let fallback: String
        switch operation {
        case .install:
            key = "error.pack.import"
            fallback = "内容包导入失败：%@"
        case .rollback:
            key = "error.pack.rollback"
            fallback = "内容包回滚失败：%@"
        case .remove:
            key = "error.pack.remove"
            fallback = "内容包移除失败：%@"
        case .restoreRemoval:
            key = "error.pack.restore"
            fallback = "内容包恢复失败：%@"
        case .purgeRecovery:
            key = "error.pack.purgeRecovery"
            fallback = "恢复项清理失败：%@"
        case .exportBackup:
            key = "error.backup.export"
            fallback = "备份导出失败：%@"
        case .inspectBackup:
            key = "error.backup.inspect"
            fallback = "备份检查失败：%@"
        case .restoreBackup:
            key = "error.backup.restore"
            fallback = "备份恢复失败：%@"
        }
        return String(
            format: CompanionLocalization.string(key: key, fallback: fallback),
            locale: Locale.current,
            arguments: [presentedError]
        )
    }
}
