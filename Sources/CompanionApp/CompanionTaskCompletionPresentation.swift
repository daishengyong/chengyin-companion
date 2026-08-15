import CompanionContracts
import Foundation

struct CompanionTaskCompletionPresentation: Equatable {
    let text: String
    let action: CompanionAction

    static func celebration(
        tier: CompanionCelebrationTier,
        context: CompanionCompletionContext?,
        addressed: Bool,
        allowsRomanticGestures: Bool,
        variation: UInt64
    ) -> CompanionTaskCompletionPresentation {
        let plan = CompanionTaskCompletionPolicy.celebration(
            tier: tier,
            recoveredAfterFailure: context?.recoveredAfterFailure == true,
            allowsRomanticGestures: allowsRomanticGestures,
            variation: variation
        )
        return CompanionTaskCompletionPresentation(
            text: localizedText(for: plan.copy, addressed: addressed),
            action: action(for: plan.rewardBeat)
        )
    }

    static func reply(
        to gesture: CompanionCompletionReplyGesture,
        allowsRomanticGestures: Bool
    ) -> CompanionTaskCompletionPresentation {
        let plan = CompanionTaskCompletionPolicy.reply(
            to: gesture,
            allowsRomanticGestures: allowsRomanticGestures
        )
        return CompanionTaskCompletionPresentation(
            text: "",
            action: action(for: plan.rewardBeat)
        )
    }

    private static func localizedText(
        for intent: CompanionTaskCompletionCopyIntent,
        addressed: Bool
    ) -> String {
        let prefix = addressed
            ? CompanionLocalization.string(
                key: "completion.address.prefix",
                fallback: "亲爱的，"
            )
            : ""
        let body: String
        switch intent {
        case .recovered:
            body = CompanionLocalization.string(
                key: "completion.line.recovered",
                fallback: "这次漂亮。你刚才没有放弃，我看见了。"
            )
        case .quiet:
            body = CompanionLocalization.string(
                key: "completion.line.quiet",
                fallback: "收工。奖励是这一眼，不许躲。"
            )
        case .warm:
            body = CompanionLocalization.string(
                key: "completion.line.warm",
                fallback: "做得漂亮，过来领一下专属表扬。"
            )
        case .playful:
            body = CompanionLocalization.string(
                key: "completion.line.playful",
                fallback: "今天的节奏很好，奖励升级啦。"
            )
        case .signature:
            body = CompanionLocalization.string(
                key: "completion.line.signature",
                fallback: "这一关值得认真庆祝，剩下的交给我。"
            )
        }
        return prefix + body
    }

    private static func action(
        for beat: CompanionTaskCompletionRewardBeat
    ) -> CompanionAction {
        switch beat {
        case .clap: .clap
        case .cheer: .cheer
        case .jump: .jump
        case .twirl: .twirl
        case .heart: .heart
        case .kiss: .kiss
        }
    }
}
