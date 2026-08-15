#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Foundation

enum CompanionLifestylePresentation {
    static func status(
        for outcome: CompanionLifestyleRuntimeOutcome,
        now: Date
    ) -> String {
        switch outcome {
        case .disabled:
            text(
                "care.status.disabled",
                "主动关心已关闭，点击和 Codex 联动仍可用"
            )
        case let .paused(until):
            format(
                "care.status.pausedUntil",
                "主动关心已暂停到 %@",
                shortTime(until)
            )
        case .away:
            text("care.status.away", "你离开时不追着提醒，回来后再继续")
        case .returnedSettling:
            text("care.status.returnedSettling", "欢迎回来，先让你安静进入状态")
        case let .returnedCoolingDown(until):
            format(
                "care.status.returnedMinutes",
                "欢迎回来，约 %d 分钟后恢复关心",
                max(1, Int(until.timeIntervalSince(now) / 60))
            )
        case .play:
            text("care.status.scheduling", "正在安排下一次关心")
        case let .defer(kind, until):
            nextCareText(kind: kind, at: until, now: now)
        case let .silence(reason):
            silenceText(reason)
        }
    }

    static func delivered(
        _ kind: CompanionLifestyleReminderKind
    ) -> String {
        format("care.status.delivered", "刚刚送达：%@", kindLabel(kind))
    }

    static func paused(until: Date) -> String {
        format(
            "care.status.pausedUntil",
            "主动关心已暂停到 %@",
            shortTime(until)
        )
    }

    private static func nextCareText(
        kind: CompanionLifestyleReminderKind,
        at date: Date,
        now: Date
    ) -> String {
        let interval = max(0, date.timeIntervalSince(now))
        if interval < 90 * 60 {
            return format(
                "care.next.minutes",
                "下一次关心：约 %d 分钟后 · %@",
                max(1, Int(ceil(interval / 60))),
                kindLabel(kind)
            )
        }
        return format(
            "care.next.time",
            "下一次关心：%@ · %@",
            shortTime(date),
            kindLabel(kind)
        )
    }

    private static func kindLabel(
        _ kind: CompanionLifestyleReminderKind
    ) -> String {
        switch kind {
        case .morningGreeting:
            text("care.kind.morning", "早安")
        case .hydration:
            text("care.kind.hydration", "喝水")
        case .sedentaryMovement:
            text("care.kind.movement", "起来走走")
        case .eyeRest:
            text("care.kind.eyeRest", "让眼睛休息")
        case .focusEncouragement:
            text("care.kind.encouragement", "加油鼓励")
        case .hourlyTimeAnnouncement:
            text("care.kind.hourly", "整点陪伴")
        case .halfHourlyTimeAnnouncement:
            text("care.kind.halfHourly", "半点陪伴")
        case .lunch:
            text("care.kind.lunch", "午餐关心")
        case .eveningWindDown:
            text("care.kind.evening", "晚间收尾")
        case .lateNightRest:
            text("care.kind.lateNight", "早点休息")
        }
    }

    private static func silenceText(
        _ reason: CompanionLifestyleSilenceReason
    ) -> String {
        switch reason {
        case .quietHours:
            text("care.silence.quietHours", "安静陪伴中 · 8:30 后恢复主动关心")
        case .mediaPlayback, .gameplay:
            text("care.status.afterInteraction", "当前互动结束后再关心你")
        case .dailyLimitsReached:
            text("care.silence.dailyLimit", "今天的主动关心已经足够，剩下时间安静陪着你")
        case .narrowTimeWindowBlocked:
            text("care.silence.windowMissed", "这次时机让过，不打断你")
        case .noEnabledReminders:
            text("care.silence.disabled", "主动关心已关闭")
        case .noEligibleReminder:
            text("care.silence.noEligible", "澄音安静陪着你")
        }
    }

    private static func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private static func text(_ key: String, _ fallback: String) -> String {
#if COMPANION_STANDALONE_SMOKE
        fallback
#else
        CompanionLocalization.string(key: key, fallback: fallback)
#endif
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
