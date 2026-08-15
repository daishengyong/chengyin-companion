/// Stable trigger vocabulary and feature-compatibility policy shared by the
/// validator and creator-facing contract checks.
enum ContentPackTriggerContract {
    static let workdayMinimumAppVersion = "0.19.42"

    private static let builtIn: Set<String> = [
        "idle", "singleTap", "doubleTap", "longPressRelease", "drag", "fling",
        "taskStarted", "taskLongRunning", "taskCompleted", "taskFailed",
        "taskCancelled", "responseReady", "morning", "evening",
        "hydration", "stretch"
    ]
    private static let scopedPrefixes = ["gameWon:", "manual:"]
    private static let versionedWorkday: Set<String> = [
        "taskStarted", "taskLongRunning", "taskCancelled", "responseReady"
    ]

    static func isAllowed(_ trigger: String) -> Bool {
        builtIn.contains(trigger)
            || scopedPrefixes.contains {
                trigger.hasPrefix($0) && trigger.count > $0.count
            }
    }

    static func validateCompatibility(
        triggers: [String],
        minimumVersion: SemanticVersion
    ) throws {
        guard let trigger = triggers.first(where: versionedWorkday.contains),
              let required = SemanticVersion(workdayMinimumAppVersion),
              minimumVersion < required else { return }
        throw ContentPackValidationError.workdayTriggerRequiresAppVersion(
            trigger: trigger,
            required: workdayMinimumAppVersion
        )
    }
}
