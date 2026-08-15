import CompanionContracts
import Foundation

enum CompanionCopy {
    static var workdayTitle: String {
        localized(key: "workday.title", fallback: "今天的共同工作日")
    }

    static var workdayStarted: String {
        localized(key: "workday.metric.started", fallback: "共同开始")
    }

    static var workdayCompleted: String {
        localized(key: "workday.metric.completed", fallback: "真正完成")
    }

    static var workdayResponses: String {
        localized(key: "workday.metric.responses", fallback: "新结果")
    }

    static var workdayChallenges: String {
        localized(key: "workday.metric.challenges", fallback: "遇到阻碍")
    }

    static var workdayRecoveries: String {
        localized(key: "workday.metric.recoveries", fallback: "重新拿下")
    }

    static var workdayFocusMinutes: String {
        localized(key: "workday.metric.focus", fallback: "共同专注分钟")
    }

    static var workdayPrivacyNote: String {
        localized(
            key: "workday.privacy",
            fallback: "只记录次数和时长，不保存任务标题、代码、Prompt 或路径。"
        )
    }

    static var workdayForget: String {
        localized(key: "workday.forget", fallback: "忘记今天的记录")
    }

    static var workdayForgetConfirmation: String {
        localized(
            key: "workday.forget.confirmation",
            fallback: "确定忘记今天的共同工作日吗？"
        )
    }

    static var workdayForgetExplanation: String {
        localized(
            key: "workday.forget.explanation",
            fallback: "今天的次数、时长和恢复记录会从主记录与本地回滚快照中一起删除。"
        )
    }

    static var workdayForgetConfirmButton: String {
        localized(key: "workday.forget.confirm", fallback: "确认忘记")
    }

    static var cancel: String {
        localized(key: "common.cancel", fallback: "取消")
    }

    static var workdayForgotten: String {
        localized(key: "workday.forgotten", fallback: "今天的共同工作日已经忘记")
    }

    static var workdayForgottenShort: String {
        localized(key: "workday.forgotten.short", fallback: "已经忘记")
    }

    static var relationshipForget: String {
        localized(key: "relationship.forget", fallback: "忘记所有共同回忆")
    }

    static var relationshipForgetConfirmation: String {
        localized(
            key: "relationship.forget.confirmation",
            fallback: "确定忘记所有共同回忆吗？"
        )
    }

    static var relationshipForgetExplanation: String {
        localized(
            key: "relationship.forget.explanation",
            fallback: "共同瞬间、纪念物、惊喜进度和播放历史会从主记录与回滚副本中删除；你选择的陪伴语气会保留。"
        )
    }

    static var relationshipForgetConfirmButton: String {
        localized(key: "relationship.forget.confirm", fallback: "确认全部忘记")
    }

    static var relationshipForgotten: String {
        localized(key: "relationship.forgotten", fallback: "共同回忆已经清除，陪伴语气保持不变")
    }

    static var relationshipForgottenShort: String {
        localized(key: "relationship.forgotten.short", fallback: "重新认识彼此")
    }

    static func relationshipMemoryScopeLabel(
        _ scope: CompanionRelationshipMemoryScope
    ) -> String {
        switch scope {
        case .sharedProgress:
            localized(key: "relationship.scope.progress", fallback: "共同瞬间")
        case .sessionChemistry:
            localized(key: "relationship.scope.chemistry", fallback: "本次默契")
        case .surpriseProgress:
            localized(key: "relationship.scope.surprise", fallback: "惊喜进度")
        case .mementos:
            localized(key: "relationship.scope.mementos", fallback: "已发现的纪念物")
        case .playbackHistory:
            localized(key: "relationship.scope.playback", fallback: "播放与防重复历史")
        }
    }

    static func relationshipForgetScopeConfirmation(
        _ scope: CompanionRelationshipMemoryScope
    ) -> String {
        format(
            key: "relationship.scope.confirmation",
            fallback: "确定清除“%@”吗？",
            relationshipMemoryScopeLabel(scope)
        )
    }

    static func relationshipScopeForgotten(
        _ scope: CompanionRelationshipMemoryScope
    ) -> String {
        format(
            key: "relationship.scope.forgotten",
            fallback: "%@已经从主记录和回滚副本中清除",
            relationshipMemoryScopeLabel(scope)
        )
    }

    static func relationshipForgetScopeButton(
        _ scope: CompanionRelationshipMemoryScope
    ) -> String {
        format(
            key: "relationship.scope.clear.button",
            fallback: "清除%@",
            relationshipMemoryScopeLabel(scope)
        )
    }

    static var careForget: String {
        localized(key: "care.forget", fallback: "重置关心节奏记录")
    }

    static var careForgetConfirmation: String {
        localized(
            key: "care.forget.confirmation",
            fallback: "重新从现在安排关心节奏吗？"
        )
    }

    static var careForgetExplanation: String {
        localized(
            key: "care.forget.explanation",
            fallback: "最近提醒时间、分类冷却和今日次数会被清除；提醒开关、节奏偏好和当前安静设置保持不变。"
        )
    }

    static func workdayCompact(completedCount: UInt64) -> String {
        format(
            key: "workday.compact.completed",
            fallback: "今日 %llu",
            completedCount
        )
    }

    static func workdayPresence(completedCount: UInt64) -> String {
        format(
            key: "workday.presence.completed",
            fallback: "今天一起完成了 %llu 次，澄音继续陪着你",
            completedCount
        )
    }

    static func workdaySummary(state: CompanionWorkdayStateV1) -> String {
        let minutes = state.focusedDurationSeconds / 60
        if state.completedCount == 0,
           state.startedCount == 0,
           state.responseReadyCount == 0 {
            return localized(
                key: "workday.summary.empty",
                fallback: "今天的共同工作日刚刚开始"
            )
        }
        return format(
            key: "workday.summary",
            fallback: "今天共同开始 %llu 次，完成 %llu 次，专注约 %llu 分钟",
            state.startedCount,
            state.completedCount,
            minutes
        )
    }

    static func localized(key: String, fallback: String) -> String {
        CompanionLocalization.string(key: key, fallback: fallback)
    }

    private static func format(
        key: String,
        fallback: String,
        _ arguments: CVarArg...
    ) -> String {
        let template = localized(key: key, fallback: fallback)
        return String(
            format: template,
            locale: Locale.current,
            arguments: arguments
        )
    }
}
