import Foundation

/// Keeps a user-requested surprise distinct from scheduled care and clock
/// announcements. The candidates are all visual play moments; none can sound
/// like hydration, movement or timekeeping triggered by a direct click.
public struct CompanionDirectSurprisePolicy: Sendable {
    public init() {}

    public func candidates(
        daypart: CompanionDaypart,
        relationshipTone: CompanionRelationshipTone
    ) -> [CompanionDirectedPetMoment] {
        switch relationshipTone {
        case .calmPeer:
            return daypart == .night
                ? [.rainPortal, .underseaRoom]
                : [.rainPortal, .kitchen]
        case .warmSupport:
            return daypart == .night
                ? [.moonDance, .rainPortal, .vanity]
                : [.kitchen, .vanity, .moonDance]
        case .playfulSpark:
            return daypart == .night
                ? [.moonDance, .underseaRoom, .vanity]
                : [.moonDance, .vanity, .kitchen]
        case .romanceLite:
            return daypart == .night
                ? [.lunarOrbit, .underseaRoom, .bedtime, .bed]
                : [.moonDance, .vanity, .kitchen, .lunarOrbit]
        }
    }
}
