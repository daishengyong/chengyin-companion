import Foundation

/// Localized presentation copy for semantic event kinds. Keeping this mapping
/// outside the view model prevents the orchestration type from becoming the
/// source of truth for user-facing event semantics.
enum CompanionEventPresentation {
    static func status(for event: CompanionEventKind) -> String {
        switch event {
        case .hydration: text("event.status.hydration", "澄音提醒你喝水")
        case .movement: text("event.status.movement", "澄音陪你活动一下")
        case .eyeRest: text("event.status.eyeRest", "澄音陪你放松眼睛")
        case .focusEncouragement: text("event.status.encouragement", "澄音给你补一点能量")
        case .timeAnnouncement: text("event.status.time", "澄音来报时")
        case .lunch: text("event.status.lunch", "澄音提醒你好好吃饭")
        case .eveningWindDown: text("event.status.evening", "澄音陪你收好今天")
        case .flirt: text("event.status.flirt", "澄音偷偷夸你")
        case .taskComplete: text("event.status.taskComplete", "Codex 任务已完成")
        case .taskFailed: text("event.status.taskFailed", "澄音陪你再试一次")
        case .replyReady: text("event.status.replyReady", "Codex 已回复")
        case .morning: text("event.status.morning", "早安问候")
        case .lateNight: text("event.status.lateNight", "今晚该收尾啦")
        case .welcome: text("event.status.welcome", "澄音回来啦")
        case .petHold: text("event.status.petHold", "正在抚摸澄音")
        case .petPickup: text("event.status.petPickup", "抱起澄音")
        case .petNudge: text("event.status.petNudge", "轻轻逗她")
        case .petFling: text("event.status.petFling", "把澄音甩飞")
        case .petDock: text("event.status.petDock", "澄音坐到屏幕边缘")
        case .petLift: text("event.status.petLift", "把澄音举高")
        case .petSettle: text("event.status.petSettle", "把澄音放稳")
        case .petGameStart: text("event.status.gameStart", "抓住我小游戏开始")
        case .petGameCatch: text("event.status.gameCatch", "抓到澄音")
        case .petGameEnd: text("event.status.gameEnd", "抓住我小游戏结束")
        case .petHideStart: text("event.status.hideStart", "躲猫猫开始")
        case .petHideFound: text("event.status.hideFound", "找到澄音")
        case .petHideEnd: text("event.status.hideEnd", "躲猫猫结束")
        case .petComboStart: text("event.status.comboStart", "动作连招开始")
        case .petComboStep: text("event.status.comboStep", "动作连招接续")
        case .petComboWrong: text("event.status.comboWrong", "动作连招顺序重置")
        case .petComboEnd: text("event.status.comboEnd", "动作连招结束")
        case .petTraceStart: text("event.status.traceStart", "心形轨迹开始")
        case .petTraceStep: text("event.status.traceStep", "心形轨迹接续")
        case .petTraceWrong: text("event.status.traceWrong", "心形轨迹断开")
        case .petTraceEnd: text("event.status.traceEnd", "心形轨迹结束")
        case .petRhythmStart: text("event.status.rhythmStart", "心跳节拍开始")
        case .petRhythmHit: text("event.status.rhythmHit", "心跳节拍命中")
        case .petRhythmMiss: text("event.status.rhythmMiss", "心跳节拍失误")
        case .petRhythmEnd: text("event.status.rhythmEnd", "心跳节拍结束")
        case .petFeedStart: text("event.status.feedStart", "投喂时刻开始")
        case .petFeedBite: text("event.status.feedBite", "澄音收到点心")
        case .petFeedMiss: text("event.status.feedMiss", "点心没有递到")
        case .petFeedEnd: text("event.status.feedEnd", "投喂时刻结束")
        }
    }

    private static func text(_ key: String, _ fallback: String) -> String {
        CompanionLocalization.string(key: key, fallback: fallback)
    }
}
