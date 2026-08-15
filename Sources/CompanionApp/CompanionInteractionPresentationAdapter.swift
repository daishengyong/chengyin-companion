import CompanionContracts

private func interactionText(_ key: String, _ fallback: String) -> String {
    CompanionLocalization.string(key: key, fallback: fallback)
}

/// App-only mapping between Core interaction decisions and presentation models.
///
/// Keeping this adapter outside the view model makes the Core/App boundary
/// visible without teaching deterministic policy about media or window types.
enum PetMoment {
    case action(CompanionAction)
    case scene(CompanionScene)
    case miniScene(CompanionMiniScene)

    var key: String {
        switch self {
        case let .action(action): "action:\(action.rawValue)"
        case let .scene(scene): "scene:\(scene.rawValue)"
        case let .miniScene(scene): "mini:\(scene.rawValue)"
        }
    }

    init(_ directedMoment: CompanionDirectedPetMoment) {
        switch directedMoment {
        case .drink:
            self = .action(.drink)
        case .stretch:
            self = .action(.stretch)
        case .clap:
            self = .action(.clap)
        case .jump:
            self = .action(.jump)
        case .twirl:
            self = .action(.twirl)
        case .laugh:
            self = .action(.laugh)
        case .heart:
            self = .action(.heart)
        case .kiss:
            self = .action(.kiss)
        case .cheer:
            self = .action(.cheer)
        case .moonDance:
            self = .scene(.moonDance)
        case .bedtime:
            self = .scene(.bedtime)
        case .lunarOrbit:
            self = .scene(.lunarOrbit)
        case .underseaRoom:
            self = .scene(.underseaRoom)
        case .timeCafe:
            self = .scene(.timeCafe)
        case .rainPortal:
            self = .scene(.rainPortal)
        case .kitchen:
            self = .miniScene(.kitchen)
        case .bed:
            self = .miniScene(.bed)
        case .workout:
            self = .miniScene(.workout)
        case .vanity:
            self = .miniScene(.vanity)
        }
    }
}

extension CompanionAction {
    var playfulCaption: String {
        switch self {
        case .drink: interactionText("action.drink.caption", "陪我喝一小口，碰杯。")
        case .stretch: interactionText("action.stretch.caption", "来，跟我一起把肩膀伸展开。")
        case .clap: interactionText("action.clap.caption", "这两下掌声专门送给你。")
        case .jump: interactionText("action.jump.caption", "抓到你啦，陪我开心一下。")
        case .twirl: interactionText("action.twirl.caption", "看好，我只转一圈给你看。")
        case .laugh: interactionText("action.laugh.caption", "你一叫我，我就忍不住开心。")
        case .heart: interactionText("action.heart.caption", "这颗心先放你这里保管。")
        case .kiss: interactionText("action.kiss.caption", "靠近一点，奖励你一个飞吻。")
        case .cheer: interactionText("action.cheer.caption", "再给你加一点能量。")
        }
    }
}

extension PetMood {
    var interactionDirectorMood: CompanionInteractionMood {
        switch self {
        case .calm:
            .calm
        case .curious:
            .curious
        case .playful:
            .playful
        case .affectionate:
            .affectionate
        case .focused:
            .focused
        case .sleepy:
            .sleepy
        case .celebrating:
            .celebrating
        }
    }
}

extension CompanionDisplayMode {
    var backupPresentationMode: CompanionPresentationMode {
        switch self {
        case .head: .pet
        case .compact: .stage
        case .full: .fullscreen
        }
    }

    init(_ backupMode: CompanionPresentationMode) {
        switch backupMode {
        case .pet: self = .head
        case .stage: self = .compact
        case .fullscreen: self = .full
        }
    }
}

extension CompanionPlaybackMode {
    var backupPlaybackPreference: CompanionPlaybackPreference {
        switch self {
        case .audioVisual: .audiovisual
        case .audioOnly: .audioOnly
        }
    }

    init(_ preference: CompanionPlaybackPreference) {
        switch preference {
        case .audiovisual: self = .audioVisual
        case .audioOnly: self = .audioOnly
        }
    }
}

extension CompanionCareCadence {
    var backupCareCadence: CompanionCareCadencePreference {
        switch self {
        case .gentle: .gentle
        case .standard: .standard
        case .lively: .lively
        }
    }

    init(_ preference: CompanionCareCadencePreference) {
        switch preference {
        case .gentle: self = .gentle
        case .standard: self = .standard
        case .lively: self = .lively
        }
    }
}
