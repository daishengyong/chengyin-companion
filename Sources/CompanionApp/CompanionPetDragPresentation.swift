import CompanionContracts
import Foundation

/// Side-effect-free localization and App-type projection for a Core drag plan.
struct CompanionPetDragPresentation {
    let cue: CompanionEventKind
    let mood: PetMood
    let effectSymbol: String
    let effectText: String
    let pose: PetPose

    static func presentation(
        for plan: CompanionPetDragPlan
    ) -> CompanionPetDragPresentation {
        let cue: CompanionEventKind
        let mood: PetMood
        let symbol: String
        let text: String

        switch plan.feedback {
        case .fling:
            cue = .petFling
            mood = .playful
            symbol = "tornado"
            text = plan.dockEdge.map {
                CompanionLocalization.format(
                    key: "effect.pet.flingDock",
                    fallback: "转着落在%@啦",
                    dockLabel($0)
                )
            } ?? localizedText("effect.pet.dizzy", "转晕啦")

        case .dock:
            cue = .petDock
            mood = .curious
            symbol = plan.dockEdge == .top ? "bird.fill" : "pin.fill"
            text = CompanionLocalization.format(
                key: "effect.pet.docked",
                fallback: "我在%@坐好啦",
                dockLabel(plan.dockEdge ?? .bottom)
            )

        case .lift:
            cue = .petLift
            mood = .playful
            symbol = "arrow.up.heart.fill"
            text = localizedText("effect.pet.lift", "飞高一点")

        case .nudge:
            cue = .petNudge
            mood = .affectionate
            symbol = "hand.tap.fill"
            text = localizedText("effect.pet.nudge", "被你碰到啦")

        case .settle:
            cue = .petSettle
            mood = .affectionate
            symbol = "heart.circle.fill"
            text = localizedText("effect.pet.settle", "抓稳我啦")
        }

        return CompanionPetDragPresentation(
            cue: cue,
            mood: mood,
            effectSymbol: symbol,
            effectText: text,
            pose: PetPose(
                x: CGFloat(plan.pose.x),
                y: CGFloat(plan.pose.y),
                rotation: plan.pose.rotation,
                scale: CGFloat(plan.pose.scale)
            )
        )
    }

    private static func dockLabel(_ edge: CompanionWindowDockEdge) -> String {
        switch edge {
        case .left: localizedText("dock.left", "左边")
        case .right: localizedText("dock.right", "右边")
        case .top: localizedText("dock.top", "上边")
        case .bottom: localizedText("dock.bottom", "下边")
        }
    }

    private static func localizedText(_ key: String, _ fallback: String) -> String {
        CompanionLocalization.string(key: key, fallback: fallback)
    }
}
