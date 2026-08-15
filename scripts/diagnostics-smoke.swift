import Foundation

@main
enum CompanionDiagnosticsSmoke {
    static func main() throws {
        var playbackHealth = CompanionPlaybackHealthAccumulator()
        let attempt = playbackHealth.beginAttempt()
        _ = playbackHealth.recordFirstFrame(for: attempt, milliseconds: 420)
        _ = playbackHealth.finishAttempt(attempt, reason: .ended)
        let snapshot = CompanionDiagnosticSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            appVersion: "0.20.0",
            buildNumber: "40",
            buildIdentity: "0.20.0+40.abcdef123456",
            operatingSystem: "macOS 26\nnewline-injection",
            architecture: "arm64",
            localeIdentifier: "zh-Hans",
            displayMode: "head",
            presentationAppearance: "transparent",
            displayTargetMode: "follow-window",
            playbackMode: "audiovisual",
            reducedDynamicEffectsEnabled: false,
            relationshipTone: "warm-support",
            remindersEnabled: true,
            careCadence: "standard",
            careMemoryRecoverySource: "backup",
            workdayRecoverySource: "safeDefault",
            quietHoursEnabled: true,
            codexCompletionAnnouncementsEnabled: true,
            eventBridgeStatusCode: "EVENT_SPOOL_ROOT_UNSAFE",
            enabledContentPackCount: 2,
            localContentPacksEnabled: true,
            labPackCount: 1,
            stablePackCount: 1,
            verifiedPackCount: 0,
            bundledVideoCount: 26,
            voiceLineCount: 159,
            playbackHealth: playbackHealth.snapshot,
            microphoneUsageDeclared: false
        )
        let report = snapshot.markdown()
        try require(report.contains("0.20.0+40.abcdef123456"), "identity missing")
        try require(report.contains("Lab 1 / Stable 1 / Verified 0"), "pack health missing")
        try require(report.contains("Display target: follow-window"), "display target missing")
        try require(report.contains("Care memory recovery: backup"), "care recovery missing")
        try require(report.contains("Workday recovery: safeDefault"), "workday recovery missing")
        try require(
            report.contains("Codex event bridge: attention [EVENT_SPOOL_ROOT_UNSAFE]"),
            "event spool recovery code missing"
        )
        try require(report.contains("First-frame P95: 420 ms / 500 ms target (withinTarget)"), "playback health missing")
        try require(report.contains("Microphone usage declared: no"), "permission state missing")
        try require(
            !report.contains("macOS 26\nnewline-injection"),
            "diagnostic value injected a report line"
        )
        for forbidden in ["/Users/", "task title", "prompt body", "api_key"] {
            try require(!report.lowercased().contains(forbidden), "private field leaked: \(forbidden)")
        }
        print("Companion diagnostics smoke passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw DiagnosticSmokeFailure(message: message) }
    }
}

private struct DiagnosticSmokeFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
