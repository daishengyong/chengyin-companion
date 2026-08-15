import CompanionContracts
import Foundation

/// One immutable support projection replaces scattered readiness counters in
/// the app composition layer. It contains capability counts and state only—no
/// paths, pack identities, event history or user work content.
struct CompanionRuntimeSupportSnapshot: Equatable, Sendable {
    let facts: CompanionRuntimeReadinessFacts
    let checks: [CompanionRuntimeReadinessCheck]

    static let empty = CompanionRuntimeSupportSnapshot(
        facts: CompanionRuntimeReadinessFacts(
            hasBuildIdentity: false,
            bundledVideoCount: 0,
            declaredVoiceLineCount: 0,
            availableVoiceLineCount: 0,
            starterContractPresent: false,
            starterPublicDistributionReady: false,
            eventBridgeReady: false,
            localContentPacksEnabled: true,
            contentLibraryHealthy: true,
            microphoneUsageDeclared: false
        ),
        checks: []
    )

    var safeRecoveryActions: [CompanionRuntimeRecoveryAction] {
        CompanionRuntimeReadiness.safeRecoveryActions(checks)
    }

    var needsAttention: Bool {
        CompanionRuntimeReadiness.needsAttention(checks)
    }

    var hasManualAttention: Bool {
        CompanionRuntimeReadiness.hasManualAttention(checks)
    }
}

enum CompanionRuntimeSupport {
    static func collect(
        bundle: Bundle = .main,
        voiceFileNames: [String],
        eventBridgeReady: Bool,
        localContentPacksEnabled: Bool,
        contentLibraryHealthy: Bool
    ) -> CompanionRuntimeSupportSnapshot {
        let identity = bundle.object(
            forInfoDictionaryKey: "ChengyinBuildIdentity"
        ) as? String
        let starterContract = starterContractStatus(bundle: bundle)
        let facts = CompanionRuntimeReadinessFacts(
            hasBuildIdentity: identity?.isEmpty == false
                && identity != "development-build",
            bundledVideoCount: bundle.urls(
                forResourcesWithExtension: "mov",
                subdirectory: nil
            )?.count ?? 0,
            declaredVoiceLineCount: voiceFileNames.count,
            availableVoiceLineCount: voiceFileNames.reduce(into: 0) { count, name in
                if VoicePackPlayer.audioURL(fileName: name) != nil {
                    count += 1
                }
            },
            starterContractPresent: starterContract.present,
            starterPublicDistributionReady: starterContract.publicDistributionReady,
            eventBridgeReady: eventBridgeReady,
            localContentPacksEnabled: localContentPacksEnabled,
            contentLibraryHealthy: contentLibraryHealthy,
            microphoneUsageDeclared: bundle.object(
                forInfoDictionaryKey: "NSMicrophoneUsageDescription"
            ) != nil
        )
        return CompanionRuntimeSupportSnapshot(
            facts: facts,
            checks: CompanionRuntimeReadiness.evaluate(facts)
        )
    }

    private static func starterContractStatus(
        bundle: Bundle
    ) -> (present: Bool, publicDistributionReady: Bool) {
        let url = bundle.url(
            forResource: "starter-media",
            withExtension: "json"
        ) ?? debugStarterManifestURL
        guard let url,
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data),
              let manifest = object as? [String: Any],
              manifest["schemaVersion"] as? Int == 1,
              manifest["contract"] as? String == "chengyin.starter-media/v1",
              manifest["packID"] as? String == "cc.chengyin.builtin-starter",
              let assets = manifest["assets"] as? [[String: Any]],
              !assets.isEmpty,
              let publicDistributionReady = manifest["publicDistributionReady"] as? Bool
        else {
            return (false, false)
        }
        return (true, publicDistributionReady)
    }

    private static var debugStarterManifestURL: URL? {
#if DEBUG
        Bundle.module.url(forResource: "starter-media", withExtension: "json")
#else
        nil
#endif
    }
}

enum CompanionRuntimeSupportCopy {
    static func summary(_ snapshot: CompanionRuntimeSupportSnapshot) -> String {
        snapshot.needsAttention
            ? text("readiness.summary.attention", "有项目需要检查")
            : text("readiness.summary.ready", "本机陪伴核心已就绪")
    }

    static func title(
        for component: CompanionRuntimeReadinessComponent
    ) -> String {
        switch component {
        case .appIdentity: text("readiness.app.title", "应用版本")
        case .starterMedia: text("readiness.media.title", "Starter 音画")
        case .starterContract:
            text("readiness.starterContract.title", "Starter 素材契约")
        case .eventBridge: text("readiness.events.title", "Codex 事件桥")
        case .contentLibrary: text("readiness.library.title", "本地内容库")
        case .privacyBoundary: text("readiness.privacy.title", "隐私边界")
        }
    }

    static func detail(
        for check: CompanionRuntimeReadinessCheck,
        snapshot: CompanionRuntimeSupportSnapshot,
        installedContentPackCount: Int
    ) -> String {
        switch check.component {
        case .appIdentity:
            return check.level == .ready
                ? text("readiness.app.ready", "版本身份完整")
                : text("readiness.app.attention", "当前是开发运行环境")
        case .starterMedia:
            return format(
                "readiness.media.detail",
                "%d 个视频 · %d/%d 条语音可用",
                snapshot.facts.bundledVideoCount,
                snapshot.facts.availableVoiceLineCount,
                snapshot.facts.declaredVoiceLineCount
            )
        case .starterContract:
            switch check.level {
            case .ready:
                return text(
                    "readiness.starterContract.ready",
                    "内置清单已装载，并通过公开候选门"
                )
            case .paused:
                return text(
                    "readiness.starterContract.paused",
                    "内置清单已装载；当前仅限个人预览"
                )
            case .attention:
                return text(
                    "readiness.starterContract.attention",
                    "内置素材清单缺失或无法读取"
                )
            }
        case .eventBridge:
            return check.level == .ready
                ? text("readiness.events.ready", "本地事件目录可读写且权限收紧")
                : text("readiness.events.attention", "本地事件目录可安全检查或修复")
        case .contentLibrary:
            switch check.level {
            case .paused:
                return text("readiness.library.paused", "Starter 模式，本地包原样保留")
            case .attention:
                return text(
                    "readiness.library.attention",
                    "内容包事务需要恢复；不会删除已安装素材"
                )
            case .ready:
                return format(
                    "readiness.library.ready",
                    "%d 个本地内容包已启用",
                    installedContentPackCount
                )
            }
        case .privacyBoundary:
            return check.level == .ready
                ? text("readiness.privacy.ready", "无麦克风权限，也不自动上传")
                : text("readiness.privacy.attention", "发现未预期的麦克风声明")
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
