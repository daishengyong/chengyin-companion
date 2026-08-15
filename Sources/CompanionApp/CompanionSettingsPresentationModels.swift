#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Foundation

struct CompanionContentPackSummary: Identifiable, Equatable {
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

    var qualityLabel: String {
        switch qualityLevel {
        case .lab:
            CompanionLocalization.string(key: "pack.quality.lab", fallback: "Lab")
        case .stable:
            CompanionLocalization.string(key: "pack.quality.stable", fallback: "Stable")
        case .verified:
            CompanionLocalization.string(key: "pack.quality.verified", fallback: "Verified")
        }
    }

    var healthLabel: String {
        switch health {
        case .pendingHealth:
            CompanionLocalization.string(
                key: "pack.health.pending",
                fallback: "等待首播验证"
            )
        case .healthy:
            CompanionLocalization.string(key: "pack.health.healthy", fallback: "播放正常")
        case .disabled:
            CompanionLocalization.string(key: "pack.health.disabled", fallback: "已安全停用")
        }
    }

    var localeLabel: String { locales.joined(separator: " · ") }

    var contributionLabel: String {
        if contributionReady {
            return CompanionLocalization.string(
                key: "pack.contribution.ready",
                fallback: "贡献证据完整"
            )
        }
        switch contributionMode {
        case .legacyV1:
            return CompanionLocalization.string(
                key: "pack.contribution.legacyV1",
                fallback: "v1 兼容 · 未推断许可"
            )
        case .compatibilityV2:
            return CompanionLocalization.string(
                key: "pack.contribution.compatibility",
                fallback: "兼容模式 · 贡献证据未完整"
            )
        case .strictV2:
            return CompanionLocalization.string(
                key: "pack.contribution.strictPending",
                fallback: "严格 v2 · 审阅或覆盖待完成"
            )
        }
    }
}

struct CompanionBackupPreview: Equatable {
    let directory: URL
    let createdAt: Date
    let appVersion: String
    let packCount: Int
}
