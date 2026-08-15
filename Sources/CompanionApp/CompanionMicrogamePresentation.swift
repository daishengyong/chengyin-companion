import CompanionContracts
import CoreGraphics
import Foundation

/// Read-only projection from the ephemeral Core session into localized UI.
///
/// It deliberately owns no timer, input, audio, haptic, window, preference or
/// relationship side effect. The view model remains the App-layer composition
/// root while views consume this focused projection through computed values.
enum CompanionMicrogamePresentation {
    static func hudText(for session: CompanionMicrogameSession) -> String {
        switch session.activeGame {
        case .feed:
            return format(
                "game.hud.feed",
                "喂 %d/3  %ds",
                session.score,
                session.secondsRemaining
            )
        case .rhythm:
            return format(
                "game.hud.rhythm",
                "拍 %d/8  ×%d",
                session.score,
                session.combo
            )
        case .heartTrace:
            return format(
                "game.hud.heart",
                "心 %d/%d  %ds",
                session.heartTraceProgress,
                CompanionMicrogameSession.heartTraceGuide.count,
                session.secondsRemaining
            )
        case .gestureCombo:
            let prompts = [
                text("game.hud.prompt.tap", "轻点"),
                text("game.hud.prompt.hold", "长按"),
                text("game.hud.prompt.fling", "甩动"),
                text("game.hud.prompt.done", "完成")
            ]
            let prompt = prompts[min(session.comboStep, prompts.count - 1)]
            return format(
                "game.hud.comboSteps",
                "连 %d/3 · %@  %ds",
                session.comboStep,
                prompt,
                session.secondsRemaining
            )
        case .hideAndSeek:
            return format(
                "game.hud.hide",
                "躲 %d/5  %ds%@",
                session.score,
                session.secondsRemaining,
                comboSuffix(session.combo)
            )
        case .catchPet, nil:
            return format(
                "game.hud.catch",
                "%d/5  %ds%@",
                session.score,
                session.secondsRemaining,
                comboSuffix(session.combo)
            )
        }
    }

    private static func comboSuffix(_ combo: Int) -> String {
        combo > 1 ? format("game.hud.combo", "  ×%d", combo) : ""
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

extension CompanionViewModel {
    var catchGameActive: Bool { microgameSession.activeGame == .catchPet }
    var catchGameScore: Int { catchGameActive ? microgameSession.score : 0 }
    var catchGameCombo: Int { catchGameActive ? microgameSession.combo : 0 }
    var catchGameSecondsRemaining: Int {
        catchGameActive ? microgameSession.secondsRemaining : 0
    }

    var hideGameActive: Bool { microgameSession.activeGame == .hideAndSeek }
    var hideGameScore: Int { hideGameActive ? microgameSession.score : 0 }
    var hideGameCombo: Int { hideGameActive ? microgameSession.combo : 0 }
    var hideGameSecondsRemaining: Int {
        hideGameActive ? microgameSession.secondsRemaining : 0
    }

    var comboGameActive: Bool { microgameSession.activeGame == .gestureCombo }
    var comboGameStep: Int { comboGameActive ? microgameSession.comboStep : 0 }
    var comboGameSecondsRemaining: Int {
        comboGameActive ? microgameSession.secondsRemaining : 0
    }

    var heartTraceGameActive: Bool {
        microgameSession.activeGame == .heartTrace
    }
    var heartTraceProgress: Int {
        heartTraceGameActive ? microgameSession.heartTraceProgress : 0
    }
    var heartTraceSecondsRemaining: Int {
        heartTraceGameActive ? microgameSession.secondsRemaining : 0
    }
    var heartTraceGuidePoints: [CGPoint] {
        CompanionMicrogameSession.heartTraceGuide.map {
            CGPoint(x: $0.x, y: $0.y)
        }
    }

    var rhythmGameActive: Bool { microgameSession.activeGame == .rhythm }
    var rhythmGameHits: Int { rhythmGameActive ? microgameSession.score : 0 }
    var rhythmGameCombo: Int { rhythmGameActive ? microgameSession.combo : 0 }
    var rhythmGameBeat: Int {
        rhythmGameActive ? microgameSession.rhythmBeat : 0
    }
    var rhythmBeatPulse: Int { microgameSession.rhythmPulse }
    var rhythmBeatReady: Bool {
        rhythmGameActive && microgameSession.rhythmReady
    }

    var feedGameActive: Bool { microgameSession.activeGame == .feed }
    var feedGameScore: Int { feedGameActive ? microgameSession.score : 0 }
    var feedGameSecondsRemaining: Int {
        feedGameActive ? microgameSession.secondsRemaining : 0
    }

    var petGameActive: Bool { microgameSession.activeGame != nil }

    var activePetGameHUDText: String {
        CompanionMicrogamePresentation.hudText(for: microgameSession)
    }
}
