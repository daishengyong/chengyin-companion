#if !COMPANION_STANDALONE_SMOKE
import CompanionContracts
#endif
import Foundation

struct CompanionLifestyleDeliveryPlan {
    let event: CompanionEventKind
    let preferredVoiceLineID: String?
}

enum CompanionLifestyleEventProjection {
    static func deliveryPlan(
        for kind: CompanionLifestyleReminderKind,
        at date: Date,
        allowsFlirtyEncouragement: Bool,
        calendar: Calendar = .current
    ) -> CompanionLifestyleDeliveryPlan {
        switch kind {
        case .morningGreeting:
            return CompanionLifestyleDeliveryPlan(event: .morning, preferredVoiceLineID: nil)
        case .hydration:
            return CompanionLifestyleDeliveryPlan(event: .hydration, preferredVoiceLineID: nil)
        case .sedentaryMovement:
            return CompanionLifestyleDeliveryPlan(event: .movement, preferredVoiceLineID: nil)
        case .eyeRest:
            return CompanionLifestyleDeliveryPlan(event: .eyeRest, preferredVoiceLineID: nil)
        case .focusEncouragement:
            return CompanionLifestyleDeliveryPlan(
                event: allowsFlirtyEncouragement ? .flirt : .focusEncouragement,
                preferredVoiceLineID: nil
            )
        case .hourlyTimeAnnouncement, .halfHourlyTimeAnnouncement:
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return CompanionLifestyleDeliveryPlan(
                event: .timeAnnouncement,
                preferredVoiceLineID: String(
                    format: "time_%02d_%02d",
                    components.hour ?? 0,
                    components.minute ?? 0
                )
            )
        case .lunch:
            return CompanionLifestyleDeliveryPlan(event: .lunch, preferredVoiceLineID: nil)
        case .eveningWindDown:
            return CompanionLifestyleDeliveryPlan(event: .eveningWindDown, preferredVoiceLineID: nil)
        case .lateNightRest:
            return CompanionLifestyleDeliveryPlan(event: .lateNight, preferredVoiceLineID: nil)
        }
    }
}
