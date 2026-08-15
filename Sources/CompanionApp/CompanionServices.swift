import AVFoundation
import CompanionContracts
import Foundation

final class VoicePackPlayer: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    var onStart: (() -> Void)?
    var onFinish: (() -> Void)?
    var onMissing: ((String) -> Void)?

    private var player: AVAudioPlayer?

    var isPlaying: Bool {
        player?.isPlaying == true
    }

    @discardableResult
    func play(fileName: String) -> TimeInterval {
        player?.stop()
        player = nil

        guard let url = Self.audioURL(fileName: fileName) else {
            onMissing?(fileName)
            onFinish?()
            return 0
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = 0.96
            player.prepareToPlay()
            self.player = player
            onStart?()
            player.play()
            return player.duration
        } catch {
            onMissing?(fileName)
            onFinish?()
            return 0
        }
    }

    func stop() {
        player?.stop()
        player = nil
        onFinish?()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        onFinish?()
    }

    static func audioURL(fileName: String) -> URL? {
        let file = fileName as NSString
        let stem = file.deletingPathExtension
        let ext = file.pathExtension
        if let url = Bundle.main.url(
            forResource: stem,
            withExtension: ext,
            subdirectory: "Audio"
        ) {
            return url
        }
        if let url = Bundle.main.url(forResource: stem, withExtension: ext) {
            return url
        }
        #if DEBUG
        if let url = Bundle.module.url(
            forResource: stem,
            withExtension: ext,
            subdirectory: "Audio"
        ) {
            return url
        }
        if let url = Bundle.module.url(forResource: stem, withExtension: ext) {
            return url
        }
        #endif
        return nil
    }
}

struct VoiceLineLibrary {
    let lines: [VoiceLine]

    static func load() -> VoiceLineLibrary {
        if let url = Bundle.main.url(forResource: "voice-lines", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let lines = try? JSONDecoder().decode([VoiceLine].self, from: data) {
            return VoiceLineLibrary(lines: lines)
        }
        #if DEBUG
        if let url = Bundle.module.url(forResource: "voice-lines", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let lines = try? JSONDecoder().decode([VoiceLine].self, from: data) {
            return VoiceLineLibrary(lines: lines)
        }
        #endif
        return VoiceLineLibrary(lines: [])
    }

    func candidates(
        for event: CompanionEventKind,
        addressedEnabled: Bool,
        excluding excludedIDs: Set<String>
    ) -> [VoiceLine] {
        let eventLines = lines.filter {
            $0.event == event && (addressedEnabled || !$0.addressed)
        }
        let fresh = eventLines.filter { !excludedIDs.contains($0.id) }
        return fresh.isEmpty ? eventLines : fresh
    }

    func candidates(
        for action: CompanionAction,
        addressedEnabled: Bool,
        excluding excludedIDs: Set<String>
    ) -> [VoiceLine] {
        let manualEvents: Set<CompanionEventKind>
        switch action {
        case .drink:
            manualEvents = [.hydration]
        case .stretch:
            manualEvents = [.movement, .eyeRest]
        case .clap, .jump, .cheer:
            manualEvents = [.focusEncouragement]
        case .twirl, .laugh, .heart, .kiss:
            manualEvents = [.flirt]
        }
        let actionLines = lines.filter {
            manualEvents.contains($0.event)
                && (addressedEnabled || !$0.addressed)
        }
        let fresh = actionLines.filter { !excludedIDs.contains($0.id) }
        return fresh.isEmpty ? actionLines : fresh
    }
}
