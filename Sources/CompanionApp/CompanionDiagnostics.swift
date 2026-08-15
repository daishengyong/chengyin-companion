import Foundation
#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif

/// A deliberately narrow support surface. It contains product/runtime facts
/// only: no paths, user names, task text, prompts, source, relationship memory,
/// event history or content-pack identifiers.
struct CompanionDiagnosticSnapshot: Equatable, Sendable {
    let generatedAt: Date
    let appVersion: String
    let buildNumber: String
    let buildIdentity: String
    let operatingSystem: String
    let architecture: String
    let localeIdentifier: String
    let displayMode: String
    let presentationAppearance: String
    let displayTargetMode: String
    let playbackMode: String
    let reducedDynamicEffectsEnabled: Bool
    let relationshipTone: String
    let remindersEnabled: Bool
    let careCadence: String
    let careMemoryRecoverySource: String
    let workdayRecoverySource: String
    let quietHoursEnabled: Bool
    let codexCompletionAnnouncementsEnabled: Bool
    let eventBridgeStatusCode: String?
    let enabledContentPackCount: Int
    let localContentPacksEnabled: Bool
    let labPackCount: Int
    let stablePackCount: Int
    let verifiedPackCount: Int
    let bundledVideoCount: Int
    let voiceLineCount: Int
    let playbackHealth: CompanionPlaybackHealthSnapshot
    let microphoneUsageDeclared: Bool

    func markdown() -> String {
        let utcFormatter = ISO8601DateFormatter()
        utcFormatter.formatOptions = [.withInternetDateTime]
        let lines = [
            "# Chengyin Companion privacy-minimal diagnostic",
            "",
            "Generated: \(utcFormatter.string(from: generatedAt))",
            "",
            "## Build",
            "- Version: \(safe(appVersion)) (\(safe(buildNumber)))",
            "- Identity: \(safe(buildIdentity))",
            "- OS: \(safe(operatingSystem))",
            "- Architecture: \(safe(architecture))",
            "- Locale: \(safe(localeIdentifier))",
            "",
            "## Runtime choices",
            "- Display: \(safe(displayMode))",
            "- Appearance: \(safe(presentationAppearance))",
            "- Display target: \(safe(displayTargetMode))",
            "- Playback: \(safe(playbackMode))",
            "- Low-impact mode: \(yesNo(reducedDynamicEffectsEnabled))",
            "- Relationship tone: \(safe(relationshipTone))",
            "- Reminders: \(yesNo(remindersEnabled)) (\(safe(careCadence)))",
            "- Care memory recovery: \(safe(careMemoryRecoverySource))",
            "- Workday recovery: \(safe(workdayRecoverySource))",
            "- Quiet hours: \(yesNo(quietHoursEnabled))",
            "- Codex work companionship: \(yesNo(codexCompletionAnnouncementsEnabled))",
            "- Codex event bridge: \(eventBridgeSummary)",
            "",
            "## Content health",
            "- Local content packs enabled: \(yesNo(localContentPacksEnabled))",
            "- Enabled local packs: \(max(0, enabledContentPackCount))",
            "- Quality: Lab \(max(0, labPackCount)) / Stable \(max(0, stablePackCount)) / Verified \(max(0, verifiedPackCount))",
            "- Bundled videos: \(max(0, bundledVideoCount))",
            "- Voice lines: \(max(0, voiceLineCount))",
            "- Playback attempts: started \(max(0, playbackHealth.startedCount)) / ready \(max(0, playbackHealth.readyCount)) / failed \(max(0, playbackHealth.failureCount)) / cancelled \(max(0, playbackHealth.cancelledCount))",
            "- Playback concurrency: active \(max(0, playbackHealth.activeAttemptCount)) / peak \(max(0, playbackHealth.peakActiveAttemptCount))",
            "- First-frame P95: \(firstFrameSummary)",
            "- Microphone usage declared: \(yesNo(microphoneUsageDeclared))",
            "",
            "## Privacy boundary",
            "This report intentionally excludes user names, file paths, Codex sessions, task text, prompts, source code, event history, relationship memory, pack identifiers and API credentials. It is generated locally and is never uploaded automatically.",
            ""
        ]
        return lines.joined(separator: "\n")
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    private var firstFrameSummary: String {
        guard let milliseconds = playbackHealth.firstFrameP95Milliseconds else {
            return "unavailable (0 bounded samples)"
        }
        return "\(max(0, milliseconds)) ms / \(max(0, playbackHealth.firstFrameTargetMilliseconds)) ms target (\(playbackHealth.firstFrameStatus.rawValue))"
    }

    private var eventBridgeSummary: String {
        guard let eventBridgeStatusCode, !eventBridgeStatusCode.isEmpty else {
            return "ready"
        }
        return "attention [\(safe(eventBridgeStatusCode))]"
    }

    private func safe(_ value: String) -> String {
        let flattened = value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "`", with: "'")
        return String(flattened.prefix(256))
    }
}
