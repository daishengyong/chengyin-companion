import CompanionContracts
import Foundation

private func workdayText(_ key: String, _ fallback: String) -> String {
    CompanionLocalization.string(key: key, fallback: fallback)
}

private func workdayFormat(
    _ key: String,
    _ fallback: String,
    _ arguments: CVarArg...
) -> String {
    String(
        format: workdayText(key, fallback),
        locale: Locale.current,
        arguments: arguments
    )
}

extension CompanionWorkdayVisualIntent {
    var appVisualState: CompanionCodexVisualState {
        switch self {
        case .idle: .idle
        case .working: .working
        case .completed: .completed
        }
    }
}

extension CompanionWorkdayMoodIntent {
    var appMood: PetMood {
        switch self {
        case .calm: .calm
        case .focused: .focused
        case .curious: .curious
        }
    }
}

extension CompanionWorkdayMilestone {
    var mementoID: String {
        switch self {
        case .firstCompletion: "task.first-complete"
        case .longFocus: "task.long-focus"
        case .threeCompletions: "task.three-in-a-day"
        case .recoveredAfterFailure: "task.recovery"
        }
    }
}

enum CompanionWorkdayPresentationCopy {
    static func status(for intent: CompanionWorkdayStatusIntent) -> String {
        switch intent {
        case .focusStarted:
            workdayText(
                "status.codex.started",
                "Codex 开始工作，澄音安静陪着你"
            )
        case .focusWorking:
            workdayText("status.codex.working", "Codex 正在工作")
        case .focusContinued:
            workdayText(
                "status.codex.progressContinued",
                "Codex 正在推进，澄音继续陪着你"
            )
        case let .longRunning(minutes):
            workdayFormat(
                "status.codex.longRunning",
                "长任务已进行约 %d 分钟，澄音不打扰地陪着你",
                minutes
            )
        case .otherWorkContinues:
            workdayText(
                "status.codex.otherWorkContinues",
                "还有任务在进行，澄音继续陪着你"
            )
        case .cancelled:
            workdayText(
                "status.codex.cancelled",
                "任务暂停了，澄音等你下一步"
            )
        case .integrationHealthy:
            workdayText("status.codex.healthy", "Codex 联动正常")
        case .integrationDisconnected:
            workdayText(
                "status.codex.disconnected",
                "Codex 联动暂时断开，其他陪伴功能仍可使用"
            )
        }
    }

    static func cueEffect(
        for cue: CompanionWorkdayContentCue
    ) -> (symbol: String, text: String) {
        switch cue {
        case .taskStarted:
            ("play.fill", workdayText("effect.workday.started", "开工"))
        case .taskLongRunning:
            ("cup.and.saucer.fill", workdayText("effect.workday.longRunning", "陪着你"))
        case .taskCancelled:
            ("pause.fill", workdayText("effect.workday.cancelled", "已暂停"))
        }
    }
}
