import Foundation

/// Stable Content Pack trigger aliases for App event kinds. New canonical
/// names lead the list; legacy scoped aliases remain as deterministic fallback.
enum CompanionEventTriggerRouting {
    static func triggers(for event: CompanionEventKind) -> [String] {
        switch event {
        case .hydration:
            ["hydration"]
        case .movement:
            ["stretch"]
        case .taskComplete:
            ["taskCompleted"]
        case .taskFailed:
            ["taskFailed"]
        case .replyReady:
            ["responseReady", "manual:event.\(event.rawValue)"]
        case .morning, .welcome:
            ["morning", "manual:event.\(event.rawValue)"]
        case .lateNight:
            ["evening", "manual:event.\(event.rawValue)"]
        case .petHold, .petSettle:
            ["longPressRelease", "manual:event.\(event.rawValue)"]
        case .petNudge, .petPickup, .petLift, .petDock:
            ["drag", "manual:event.\(event.rawValue)"]
        case .petFling:
            ["fling", "manual:event.\(event.rawValue)"]
        default:
            ["manual:event.\(event.rawValue)"]
        }
    }
}
