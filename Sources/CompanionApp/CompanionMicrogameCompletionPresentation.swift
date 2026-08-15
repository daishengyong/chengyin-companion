import CompanionContracts
import Foundation

struct CompanionMicrogameEffectPresentation: Equatable {
    let symbol: String
    let text: String
}

enum CompanionMicrogameRewardPresentation: Equatable {
    case action(CompanionAction)
    case miniScene(CompanionMiniScene)
}

struct CompanionMicrogameCompletionPresentation: Equatable {
    let status: String
    let mood: PetMood
    let effect: CompanionMicrogameEffectPresentation?
    let endCue: CompanionEventKind?
    let reward: CompanionMicrogameRewardPresentation?
}

/// Side-effect-free App projection for Core completion plans. Window changes,
/// audio playback, haptics and relationship persistence remain in the
/// composition root; this type only resolves localized presentation values.
enum CompanionMicrogameCompletionPresenter {
    static func presentation(
        for plan: CompanionMicrogameCompletionPlan,
        allowsRomanticGestures: Bool
    ) -> CompanionMicrogameCompletionPresentation {
        if plan.won {
            return CompanionMicrogameCompletionPresentation(
                status: winningStatus(for: plan.game),
                mood: mood(for: plan.mood),
                effect: winningEffect(for: plan.game),
                endCue: nil,
                reward: plan.rewardBeat.map {
                    reward(for: $0, allowsRomanticGestures: allowsRomanticGestures)
                }
            )
        }

        return CompanionMicrogameCompletionPresentation(
            status: plan.announce
                ? endingStatus(for: plan.game)
                : text("status.presence", "澄音陪着你"),
            mood: mood(for: plan.mood),
            effect: plan.announce ? endingEffect(for: plan.game) : nil,
            endCue: plan.announce ? endingCue(for: plan.game) : nil,
            reward: nil
        )
    }

    private static func mood(
        for intent: CompanionMicrogameCompletionMood
    ) -> PetMood {
        switch intent {
        case .playful: .playful
        case .affectionate: .affectionate
        case .celebrating: .celebrating
        }
    }

    private static func winningStatus(
        for game: CompanionMicrogameKind
    ) -> String {
        switch game {
        case .catchPet:
            text("status.game.catch.complete", "抓住我：五连抓完成")
        case .hideAndSeek:
            text("status.game.hide.complete", "躲猫猫：五次全部找到")
        case .gestureCombo:
            text("status.game.combo.complete", "连招完成：秘密暗号已收入回忆")
        case .heartTrace:
            text("status.game.heart.complete", "心形轨迹完成：共同纪念已保存")
        case .rhythm:
            text("status.game.rhythm.complete", "心跳节拍完成：八拍纪念已保存")
        case .feed:
            text("status.game.feed.complete", "投喂完成：厨房纪念已保存")
        }
    }

    private static func endingStatus(
        for game: CompanionMicrogameKind
    ) -> String {
        switch game {
        case .catchPet:
            text("status.game.catch.ended", "抓住我：这局结束啦")
        case .hideAndSeek:
            text("status.game.hide.ended", "躲猫猫：这局结束啦")
        case .gestureCombo:
            text("status.game.combo.ended", "连招挑战：这局结束啦")
        case .heartTrace:
            text("status.game.heart.ended", "心形轨迹：这局结束啦")
        case .rhythm:
            text("status.game.rhythm.ended", "心跳节拍：这局结束啦")
        case .feed:
            text("status.game.feed.ended", "投喂时刻：先留到下一次")
        }
    }

    private static func winningEffect(
        for game: CompanionMicrogameKind
    ) -> CompanionMicrogameEffectPresentation? {
        switch game {
        case .catchPet:
            .init(
                symbol: "crown.fill",
                text: text("effect.game.catch.reward", "五连抓！奖励到账")
            )
        case .hideAndSeek:
            .init(
                symbol: "heart.fill",
                text: text("effect.game.hide.reward", "都被你找到啦")
            )
        case .gestureCombo, .heartTrace, .rhythm, .feed:
            nil
        }
    }

    private static func endingEffect(
        for game: CompanionMicrogameKind
    ) -> CompanionMicrogameEffectPresentation? {
        switch game {
        case .catchPet:
            .init(
                symbol: "heart.fill",
                text: text("effect.game.catch.retry", "差一点，再来一局嘛")
            )
        case .hideAndSeek:
            .init(
                symbol: "eye.slash.fill",
                text: text("effect.game.hide.ended", "这局我藏赢啦")
            )
        case .gestureCombo, .heartTrace, .rhythm, .feed:
            nil
        }
    }

    private static func endingCue(
        for game: CompanionMicrogameKind
    ) -> CompanionEventKind {
        switch game {
        case .catchPet: .petGameEnd
        case .hideAndSeek: .petHideEnd
        case .gestureCombo: .petComboEnd
        case .heartTrace: .petTraceEnd
        case .rhythm: .petRhythmEnd
        case .feed: .petFeedEnd
        }
    }

    private static func reward(
        for beat: CompanionMicrogameRewardBeat,
        allowsRomanticGestures: Bool
    ) -> CompanionMicrogameRewardPresentation {
        switch beat {
        case .cheer: .action(.cheer)
        case .adaptiveAffection:
            .action(allowsRomanticGestures ? .kiss : .heart)
        case .twirl: .action(.twirl)
        case .heart: .action(.heart)
        case .jump: .action(.jump)
        case .kitchen: .miniScene(.kitchen)
        }
    }

    private static func text(_ key: String, _ fallback: String) -> String {
        CompanionLocalization.string(key: key, fallback: fallback)
    }
}
