import CompanionContracts
import Foundation

private func localizedUI(_ key: String, _ fallback: String) -> String {
    CompanionLocalization.string(key: key, fallback: fallback)
}

extension CompanionRelationshipTone {
    var label: String {
        switch self {
        case .calmPeer: localizedUI("tone.calm.label", "安静搭档")
        case .playfulSpark: localizedUI("tone.playful.label", "俏皮默契")
        case .warmSupport: localizedUI("tone.warm.label", "温柔支持")
        case .romanceLite: localizedUI("tone.romance.label", "轻浪漫")
        }
    }

    var detail: String {
        switch self {
        case .calmPeer: localizedUI("tone.calm.detail", "少打扰，以工作陪伴和简短鼓励为主。")
        case .playfulSpark: localizedUI("tone.playful.detail", "增加调皮眼神、小游戏和轻松逗趣。")
        case .warmSupport: localizedUI("tone.warm.detail", "温柔回应任务进展，但不主动使用亲昵称谓。")
        case .romanceLite: localizedUI("tone.romance.detail", "允许飞吻、亲昵称谓和晚间轻浪漫场景。")
        }
    }

    var allowsFlirtyReminders: Bool {
        self == .playfulSpark || self == .romanceLite
    }

    var allowsRomanticGestures: Bool {
        self == .romanceLite
    }

    var longPressActions: [CompanionAction] {
        allowsRomanticGestures
            ? [.kiss, .heart, .laugh]
            : [.heart, .laugh, .cheer]
    }
}

enum CompanionDisplayMode: String, Codable, CaseIterable {
    case full
    case compact
    case head

    var label: String {
        switch self {
        case .full: localizedUI("display.full", "全屏互动舞台")
        case .compact: localizedUI("display.compact", "半身陪伴")
        case .head: localizedUI("display.head", "迷你头像")
        }
    }

    var presentationMode: CompanionPresentationMode {
        switch self {
        case .full: .fullscreen
        case .compact: .stage
        case .head: .pet
        }
    }

}

extension CompanionPresentationAppearance {
    var label: String {
        switch self {
        case .transparent:
            localizedUI("appearance.transparent.label", "透明")
        case .cinematic:
            localizedUI("appearance.cinematic.label", "影院")
        case .dim:
            localizedUI("appearance.dim.label", "柔暗")
        }
    }

    var detail: String {
        switch self {
        case .transparent:
            localizedUI(
                "appearance.transparent.detail",
                "让人物自然浮在桌面上，背景完全透明。"
            )
        case .cinematic:
            localizedUI(
                "appearance.cinematic.detail",
                "使用有层次的半透明暗场，突出 16:9 场景。"
            )
        case .dim:
            localizedUI(
                "appearance.dim.detail",
                "使用稳定的深色衬底，不依赖透明材质。"
            )
        }
    }
}

enum CompanionPlaybackMode: String, Codable, CaseIterable {
    case audioVisual
    case audioOnly

    var label: String {
        switch self {
        case .audioVisual: localizedUI("playback.audiovisual", "音画同步")
        case .audioOnly: localizedUI("playback.audioonly", "仅声音")
        }
    }

    var systemImage: String {
        switch self {
        case .audioVisual: "play.rectangle.fill"
        case .audioOnly: "speaker.wave.2.fill"
        }
    }
}

enum CompanionCareCadence: String, Codable, CaseIterable {
    case gentle
    case standard
    case lively

    var label: String {
        switch self {
        case .gentle: localizedUI("cadence.gentle.label", "安静")
        case .standard: localizedUI("cadence.standard.label", "标准")
        case .lively: localizedUI("cadence.lively.label", "积极")
        }
    }

    var detail: String {
        switch self {
        case .gentle: localizedUI("cadence.gentle.detail", "更少打断，约每 90–120 分钟关心一次。")
        case .standard: localizedUI("cadence.standard.detail", "健康提醒与鼓励错开，约每 50–90 分钟一次。")
        case .lively: localizedUI("cadence.lively.detail", "更有存在感，仍保持至少 15 分钟间隔。")
        }
    }
}

enum PetMood: String, Codable, CaseIterable {
    case calm
    case curious
    case playful
    case affectionate
    case focused
    case sleepy
    case celebrating

    var label: String {
        switch self {
        case .calm: localizedUI("mood.calm", "安静陪伴")
        case .curious: localizedUI("mood.curious", "好奇地看着你")
        case .playful: localizedUI("mood.playful", "想和你玩")
        case .affectionate: localizedUI("mood.affectionate", "被你哄开心了")
        case .focused: localizedUI("mood.focused", "专注陪伴")
        case .sleepy: localizedUI("mood.sleepy", "有一点困")
        case .celebrating: localizedUI("mood.celebrating", "正在庆祝")
        }
    }
}

typealias PetDockEdge = CompanionWindowDockEdge

extension CompanionWindowDockEdge {
    var label: String {
        switch self {
        case .left: localizedUI("dock.left", "左边")
        case .right: localizedUI("dock.right", "右边")
        case .top: localizedUI("dock.top", "上边")
        case .bottom: localizedUI("dock.bottom", "下边")
        }
    }
}

struct PetPose: Equatable {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rotation: Double = 0
    var scale: CGFloat = 1

    static let neutral = PetPose()
}

struct PetEffect: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let text: String
}

enum PetWindowPositionStore {
    private static let key = "chengyin.pet.window-origin"

    static func save(_ point: CGPoint) {
        UserDefaults.standard.set(
            ["x": Double(point.x), "y": Double(point.y)],
            forKey: key
        )
    }

    static func load() -> CGPoint? {
        guard
            let value = UserDefaults.standard.dictionary(forKey: key),
            let x = value["x"] as? NSNumber,
            let y = value["y"] as? NSNumber
        else { return nil }
        return CGPoint(x: x.doubleValue, y: y.doubleValue)
    }
}

enum CompanionAction: Int, Codable, CaseIterable {
    case drink = 0
    case stretch = 1
    case clap = 2
    case jump = 3
    case twirl = 4
    case laugh = 5
    case heart = 6
    case kiss = 7
    case cheer = 8

    var label: String {
        switch self {
        case .drink: localizedUI("action.drink", "喝水")
        case .stretch: localizedUI("action.stretch", "伸展")
        case .clap: localizedUI("action.clap", "鼓掌")
        case .jump: localizedUI("action.jump", "开心跳起")
        case .twirl: localizedUI("action.twirl", "转一圈")
        case .laugh: localizedUI("action.laugh", "大笑")
        case .heart: localizedUI("action.heart", "比心")
        case .kiss: localizedUI("action.kiss", "飞吻")
        case .cheer: localizedUI("action.cheer", "加油")
        }
    }

    var systemImage: String {
        switch self {
        case .drink: "drop.fill"
        case .stretch: "figure.flexibility"
        case .clap: "hands.clap.fill"
        case .jump: "figure.run"
        case .twirl: "tornado"
        case .laugh: "face.smiling.fill"
        case .heart: "heart.fill"
        case .kiss: "heart.circle.fill"
        case .cheer: "sparkles"
        }
    }

    var nativeLine: String {
        switch self {
        case .drink: localizedUI("action.drink.line", "喝口水，照顾好自己我才放心呀。")
        case .stretch: localizedUI("action.stretch.line", "起来伸个懒腰，陪我走几步，好不好？")
        case .clap: localizedUI("action.clap.line", "做得漂亮，这两下掌声只送给你。")
        case .jump: localizedUI("action.jump.line", "抓到你啦，陪我跳一下！")
        case .twirl: localizedUI("action.twirl.line", "看好啦，我只为你转这一圈。")
        case .laugh: localizedUI("action.laugh.line", "你一叫我，我就忍不住开心。")
        case .heart: localizedUI("action.heart.line", "这颗心先放你那里，不许弄丢。")
        case .kiss: localizedUI("action.kiss.line", "靠近一点，奖励你一个飞吻。")
        case .cheer: localizedUI("action.cheer.line", "再给你一点能量，加油呀。")
        }
    }

    var contentAssetID: String {
        switch self {
        case .drink: "drink"
        case .stretch: "stretch"
        case .clap: "clap"
        case .jump: "jump"
        case .twirl: "twirl"
        case .laugh: "laugh"
        case .heart: "heart"
        case .kiss: "kiss"
        case .cheer: "cheer"
        }
    }
}

enum CompanionScene: String, Codable, CaseIterable {
    case moonDance = "moon-dance"
    case bedtime
    case lunarOrbit = "lunar-orbit"
    case underseaRoom = "undersea-room"
    case timeCafe = "time-cafe"
    case rainPortal = "rain-portal"

    var label: String {
        switch self {
        case .moonDance: localizedUI("scene.moonDance", "月球上跳舞")
        case .bedtime: localizedUI("scene.bedtime", "叫我去睡觉")
        case .lunarOrbit: localizedUI("scene.lunarOrbit", "月面轨道私奔")
        case .underseaRoom: localizedUI("scene.underseaRoom", "海底玻璃房")
        case .timeCafe: localizedUI("scene.timeCafe", "时间静止咖啡馆")
        case .rainPortal: localizedUI("scene.rainPortal", "雨夜传送门")
        }
    }

    var systemImage: String {
        switch self {
        case .moonDance: "moon.stars.fill"
        case .bedtime: "bed.double.fill"
        case .lunarOrbit: "globe.asia.australia.fill"
        case .underseaRoom: "water.waves"
        case .timeCafe: "clock.badge.fill"
        case .rainPortal: "cloud.rain.fill"
        }
    }

    var resourceName: String {
        "companion-scene-\(rawValue)"
    }

    var voiceEvent: CompanionEventKind {
        switch self {
        case .moonDance, .lunarOrbit, .timeCafe, .rainPortal: .flirt
        case .bedtime, .underseaRoom: .lateNight
        }
    }

    var fallbackText: String {
        switch self {
        case .moonDance: localizedUI("scene.moonDance.line", "陪我去月球上轻轻跳一支舞，好不好？")
        case .bedtime: localizedUI("scene.bedtime.line", "忙完就过来休息吧，我把你的位置留好了。")
        case .lunarOrbit: localizedUI("scene.lunarOrbit.line", "地球太吵了，今晚陪我在月光里逃跑。")
        case .underseaRoom: localizedUI("scene.underseaRoom.line", "小声一点，整片海都在听我们说悄悄话。")
        case .timeCafe: localizedUI("scene.timeCafe.line", "我把时间停住了，现在只准你看着我。")
        case .rainPortal: localizedUI("scene.rainPortal.line", "下雨了，过来，我带你回家。")
        }
    }

    var hasNativeAudio: Bool {
        switch self {
        case .lunarOrbit, .underseaRoom, .timeCafe, .rainPortal: true
        case .moonDance, .bedtime: false
        }
    }
}

enum CompanionMiniScene: String, Codable, CaseIterable {
    case kitchen
    case bed
    case workout
    case vanity

    var label: String {
        switch self {
        case .kitchen: localizedUI("mini.kitchen", "厨房偷喂")
        case .bed: localizedUI("mini.bed", "床边留位")
        case .workout: localizedUI("mini.workout", "健身陪练")
        case .vanity: localizedUI("mini.vanity", "梳妆飞吻")
        }
    }

    var systemImage: String {
        switch self {
        case .kitchen: "fork.knife"
        case .bed: "bed.double.fill"
        case .workout: "figure.run"
        case .vanity: "sparkles"
        }
    }

    var resourceName: String {
        "companion-head-scene-\(rawValue)"
    }

    var spokenLine: String {
        switch self {
        case .kitchen: localizedUI("mini.kitchen.line", "来，张嘴，第一口给你。")
        case .bed: localizedUI("mini.bed.line", "别忙啦，过来，我给你留了位置。")
        case .workout: localizedUI("mini.workout.line", "别偷看，过来陪我练一组呀。")
        case .vanity: localizedUI("mini.vanity.line", "等我一下，今晚漂亮给你看。")
        }
    }

    var voiceEvent: CompanionEventKind {
        switch self {
        case .kitchen, .vanity: .flirt
        case .bed: .lateNight
        case .workout: .movement
        }
    }
}

enum CompanionTreat: String, Codable, CaseIterable {
    case strawberry
    case cake
    case latte
    case chocolate

    var emoji: String {
        switch self {
        case .strawberry: "🍓"
        case .cake: "🍰"
        case .latte: "☕️"
        case .chocolate: "🍫"
        }
    }

    var label: String {
        switch self {
        case .strawberry: localizedUI("treat.strawberry", "草莓")
        case .cake: localizedUI("treat.cake", "小蛋糕")
        case .latte: localizedUI("treat.latte", "热拿铁")
        case .chocolate: localizedUI("treat.chocolate", "巧克力")
        }
    }
}

enum CompanionOutfit: String, Codable, CaseIterable {
    case satin
    case sport
    case evening

    var label: String {
        switch self {
        case .satin: localizedUI("outfit.satin", "玫瑰丝缎")
        case .sport: localizedUI("outfit.sport", "元气运动")
        case .evening: localizedUI("outfit.evening", "夜色约会")
        }
    }

    var resourceName: String {
        "companion-events-\(rawValue)-alpha"
    }
}

enum CompanionEventKind: String, Codable, CaseIterable, Hashable, Sendable {
    case hydration
    case movement
    case eyeRest = "eye_rest"
    case focusEncouragement = "focus_encouragement"
    case timeAnnouncement = "time_announcement"
    case lunch
    case eveningWindDown = "evening_wind_down"
    case flirt
    case taskComplete = "task_complete"
    case taskFailed = "task_failed"
    case replyReady = "reply_ready"
    case morning
    case lateNight = "late_night"
    case welcome
    case petHold = "pet_hold"
    case petPickup = "pet_pickup"
    case petNudge = "pet_nudge"
    case petFling = "pet_fling"
    case petDock = "pet_dock"
    case petLift = "pet_lift"
    case petSettle = "pet_settle"
    case petGameStart = "pet_game_start"
    case petGameCatch = "pet_game_catch"
    case petGameEnd = "pet_game_end"
    case petHideStart = "pet_hide_start"
    case petHideFound = "pet_hide_found"
    case petHideEnd = "pet_hide_end"
    case petComboStart = "pet_combo_start"
    case petComboStep = "pet_combo_step"
    case petComboWrong = "pet_combo_wrong"
    case petComboEnd = "pet_combo_end"
    case petTraceStart = "pet_trace_start"
    case petTraceStep = "pet_trace_step"
    case petTraceWrong = "pet_trace_wrong"
    case petTraceEnd = "pet_trace_end"
    case petRhythmStart = "pet_rhythm_start"
    case petRhythmHit = "pet_rhythm_hit"
    case petRhythmMiss = "pet_rhythm_miss"
    case petRhythmEnd = "pet_rhythm_end"
    case petFeedStart = "pet_feed_start"
    case petFeedBite = "pet_feed_bite"
    case petFeedMiss = "pet_feed_miss"
    case petFeedEnd = "pet_feed_end"
}

struct VoiceLine: Codable, Identifiable, Equatable {
    let id: String
    let event: CompanionEventKind
    let action: CompanionAction
    let text: String
    let audioFile: String
    let addressed: Bool
}
