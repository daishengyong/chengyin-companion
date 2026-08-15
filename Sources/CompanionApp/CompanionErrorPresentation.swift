#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Foundation

/// Converts technical failures into privacy-safe, localized guidance while
/// preserving a stable code that users can paste into an Issue. Raw system
/// errors may include local paths, so the UI never displays them directly.
enum CompanionErrorPresentation {
    static func message(for error: Error) -> String {
        let code = code(for: error)
        let descriptor = localizedDescriptor(for: error)
        return String(format: descriptor, code)
    }

    static func code(for error: Error) -> String {
        if let coded = error as? any CompanionErrorCoding {
            return coded.companionErrorCode
        }
        if let backup = error as? CompanionBackupValidationError {
            return backup.companionErrorCode
        }
        return "COMPANION_UNEXPECTED_ERROR"
    }

    private static func localizedDescriptor(for error: Error) -> String {
        switch error {
        case is ContentPackArchiveError:
            return CompanionLocalization.string(
                key: "error.presentation.packArchive",
                fallback: "这个 .chengyinpack 归档未通过安全检查。现有内容保持不变，请重新构建归档后重试。[%@]"
            )
        case is ContentPackValidationError:
            return CompanionLocalization.string(
                key: "error.presentation.packValidation",
                fallback: "内容包未通过安全与格式检查。请用创作者验证工具修复后重试。[%@]"
            )
        case is ContentPackMediaProbeError:
            return CompanionLocalization.string(
                key: "error.presentation.packMedia",
                fallback: "有素材无法验证。请按支持的编码重新导出，再运行创作者验证。[%@]"
            )
        case let store as ContentPackStoreError:
            return storeDescriptor(store)
        case is CompanionBackupValidationError:
            return CompanionLocalization.string(
                key: "error.presentation.backupValidation",
                fallback: "这个备份无效或与当前版本不兼容。请选择其他备份，或重新导出。[%@]"
            )
        case let service as CompanionBackupServiceError:
            return backupServiceDescriptor(service)
        case let care as CompanionLifestyleMemoryAdapterError:
            return careMemoryDescriptor(care)
        case let workday as CompanionWorkdayAdapterError:
            return workdayDescriptor(workday)
        default:
            return CompanionLocalization.string(
                key: "error.presentation.unexpected",
                fallback: "操作没有完成。请重试；如果仍然失败，请在 Issue 中附上错误码。[%@]"
            )
        }
    }

    private static func storeDescriptor(_ error: ContentPackStoreError) -> String {
        switch error {
        case .noRollbackVersion, .rollbackVersionMissing:
            return CompanionLocalization.string(
                key: "error.presentation.packNoRollback",
                fallback: "没有可用的旧版本可以回滚。当前内容包保持不变。[%@]"
            )
        case .downgradeNotAllowed:
            return CompanionLocalization.string(
                key: "error.presentation.packDowngrade",
                fallback: "普通安装不能降级。请在内容库中使用“回滚”。[%@]"
            )
        case .versionConflict, .restoreConflict:
            return CompanionLocalization.string(
                key: "error.presentation.packConflict",
                fallback: "同一版本的内容不一致。请更换版本号，或恢复原始内容包。[%@]"
            )
        default:
            return CompanionLocalization.string(
                key: "error.presentation.packStore",
                fallback: "内容库未能完成这次更改，现有体验保持不变。请重试或运行健康检查。[%@]"
            )
        }
    }

    private static func backupServiceDescriptor(
        _ error: CompanionBackupServiceError
    ) -> String {
        switch error {
        case .destinationAlreadyExists:
            return CompanionLocalization.string(
                key: "error.presentation.backupDestination",
                fallback: "目标文件夹已经存在。请选择一个新名称再导出。[%@]"
            )
        case .restoreRollbackFailed:
            return CompanionLocalization.string(
                key: "error.presentation.backupRollback",
                fallback: "恢复未完成，自动回滚也需要检查。请重新启动澄音并运行健康检查。[%@]"
            )
        case .backupManifestMissing, .packPayloadMissing, .packManifestHashMismatch:
            return CompanionLocalization.string(
                key: "error.presentation.backupValidation",
                fallback: "这个备份无效或与当前版本不兼容。请选择其他备份，或重新导出。[%@]"
            )
        }
    }

    private static func careMemoryDescriptor(
        _ error: CompanionLifestyleMemoryAdapterError
    ) -> String {
        switch error {
        case .persistenceFailed:
            return CompanionLocalization.string(
                key: "error.presentation.careMemoryPersistence",
                fallback: "关心节奏未能安全保存，现有节奏保持不变。请重试或运行健康检查。[%@]"
            )
        case .resetFailed:
            return CompanionLocalization.string(
                key: "error.presentation.careMemoryReset",
                fallback: "关心节奏记录未能安全清除，原记录保持不变。请重试。[%@]"
            )
        }
    }

    private static func workdayDescriptor(
        _ error: CompanionWorkdayAdapterError
    ) -> String {
        switch error {
        case .persistenceFailed:
            return CompanionLocalization.string(
                key: "error.presentation.workdayPersistence",
                fallback: "共同工作日仍会继续显示，但这次状态未能安全保存。请重试或运行健康检查。[%@]"
            )
        case .resetFailed:
            return CompanionLocalization.string(
                key: "error.presentation.workdayReset",
                fallback: "共同工作日记录未能安全清除，原记录保持不变。请重试。[%@]"
            )
        }
    }
}
