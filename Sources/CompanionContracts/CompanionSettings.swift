import Foundation

public enum CompanionPresentationMode: String, Codable, CaseIterable, Sendable {
    case pet
    case stage
    case fullscreen
}

public enum CompanionPresentationAppearance: String, Codable, CaseIterable, Sendable {
    case transparent
    case cinematic
    case dim
}

public enum CompanionDisplayTargetMode: String, Codable, CaseIterable, Sendable {
    case followWindow = "follow-window"
    case main
    case specific
}

public struct CompanionDisplayTarget: Codable, Equatable, Hashable, Sendable {
    public let mode: CompanionDisplayTargetMode
    public let identifier: String?

    public init(mode: CompanionDisplayTargetMode, identifier: String? = nil) {
        self.mode = mode
        self.identifier = identifier
    }

    public static let followWindow = CompanionDisplayTarget(mode: .followWindow)
    public static let main = CompanionDisplayTarget(mode: .main)

    public static func specific(_ identifier: String) -> CompanionDisplayTarget {
        CompanionDisplayTarget(mode: .specific, identifier: identifier)
    }

    public var isValid: Bool {
        switch mode {
        case .followWindow, .main:
            return identifier == nil
        case .specific:
            guard let identifier else { return false }
            return Self.isValidIdentifier(identifier)
        }
    }

    public static func isValidIdentifier(_ identifier: String) -> Bool {
        guard (1...96).contains(identifier.utf8.count),
              identifier == identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return false }
        return identifier.unicodeScalars.allSatisfy {
            $0.value >= 0x21 && $0.value <= 0x7E && $0 != "/" && $0 != "\\"
        }
    }
}

public enum CompanionRelationshipTone: String, Codable, CaseIterable, Sendable {
    case calmPeer = "calm-peer"
    case playfulSpark = "playful-spark"
    case warmSupport = "warm-support"
    case romanceLite = "romance-lite"
}

public enum CompanionPlaybackPreference: String, Codable, CaseIterable, Sendable {
    case audiovisual
    case audioOnly = "audio-only"
}

public enum CompanionCareCadencePreference: String, Codable, CaseIterable, Sendable {
    case gentle
    case standard
    case lively
}

public struct CompanionSettingsV1: Codable, Equatable, Sendable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var personaId: String
    public var relationshipTone: CompanionRelationshipTone
    public var locale: String
    public var presentationMode: CompanionPresentationMode
    public var presentationAppearance: CompanionPresentationAppearance
    public var displayTarget: CompanionDisplayTarget
    public var soundEnabled: Bool
    public var interactionEnabled: Bool
    public var sharingPromptEnabled: Bool
    public var playbackPreference: CompanionPlaybackPreference
    public var reducedDynamicEffectsEnabled: Bool
    public var remindersEnabled: Bool
    public var careCadence: CompanionCareCadencePreference
    public var timeAnnouncementsEnabled: Bool
    public var halfHourlyAnnouncementsEnabled: Bool
    public var quietHoursEnabled: Bool
    public var flirtyRemindersEnabled: Bool
    public var codexCompletionAnnouncementsEnabled: Bool
    public var usePetName: Bool
    public var randomOutfitsEnabled: Bool
    public var localContentPacksEnabled: Bool
    public var learnedGestureIDs: [String]

    public init(
        schemaVersion: Int = CompanionSettingsV1.schemaVersion,
        personaId: String = "starter.c01",
        relationshipTone: CompanionRelationshipTone = .warmSupport,
        locale: String = "en",
        presentationMode: CompanionPresentationMode = .pet,
        presentationAppearance: CompanionPresentationAppearance = .transparent,
        displayTarget: CompanionDisplayTarget = .followWindow,
        soundEnabled: Bool = true,
        interactionEnabled: Bool = true,
        sharingPromptEnabled: Bool = false,
        playbackPreference: CompanionPlaybackPreference = .audiovisual,
        reducedDynamicEffectsEnabled: Bool = false,
        remindersEnabled: Bool = true,
        careCadence: CompanionCareCadencePreference = .standard,
        timeAnnouncementsEnabled: Bool = true,
        halfHourlyAnnouncementsEnabled: Bool = false,
        quietHoursEnabled: Bool = true,
        flirtyRemindersEnabled: Bool = false,
        codexCompletionAnnouncementsEnabled: Bool = true,
        usePetName: Bool = false,
        randomOutfitsEnabled: Bool = true,
        localContentPacksEnabled: Bool = true,
        learnedGestureIDs: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.personaId = personaId
        self.relationshipTone = relationshipTone
        self.locale = locale
        self.presentationMode = presentationMode
        self.presentationAppearance = presentationAppearance
        self.displayTarget = displayTarget
        self.soundEnabled = soundEnabled
        self.interactionEnabled = interactionEnabled
        self.sharingPromptEnabled = sharingPromptEnabled
        self.playbackPreference = playbackPreference
        self.reducedDynamicEffectsEnabled = reducedDynamicEffectsEnabled
        self.remindersEnabled = remindersEnabled
        self.careCadence = careCadence
        self.timeAnnouncementsEnabled = timeAnnouncementsEnabled
        self.halfHourlyAnnouncementsEnabled = halfHourlyAnnouncementsEnabled
        self.quietHoursEnabled = quietHoursEnabled
        self.flirtyRemindersEnabled = flirtyRemindersEnabled
        self.codexCompletionAnnouncementsEnabled = codexCompletionAnnouncementsEnabled
        self.usePetName = usePetName
        self.randomOutfitsEnabled = randomOutfitsEnabled
        self.localContentPacksEnabled = localContentPacksEnabled
        self.learnedGestureIDs = learnedGestureIDs
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case personaId
        case relationshipTone
        case locale
        case presentationMode
        case presentationAppearance
        case displayTarget
        case soundEnabled
        case interactionEnabled
        case sharingPromptEnabled
        case playbackPreference
        case reducedDynamicEffectsEnabled
        case remindersEnabled
        case careCadence
        case timeAnnouncementsEnabled
        case halfHourlyAnnouncementsEnabled
        case quietHoursEnabled
        case flirtyRemindersEnabled
        case codexCompletionAnnouncementsEnabled
        case usePetName
        case randomOutfitsEnabled
        case localContentPacksEnabled
        case learnedGestureIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.schemaVersion
        personaId = try container.decodeIfPresent(String.self, forKey: .personaId)
            ?? "starter.c01"
        relationshipTone = try container.decodeIfPresent(
            CompanionRelationshipTone.self,
            forKey: .relationshipTone
        ) ?? .warmSupport
        locale = try container.decodeIfPresent(String.self, forKey: .locale) ?? "en"
        presentationMode = try container.decodeIfPresent(
            CompanionPresentationMode.self,
            forKey: .presentationMode
        ) ?? .pet
        presentationAppearance = try container.decodeIfPresent(
            CompanionPresentationAppearance.self,
            forKey: .presentationAppearance
        ) ?? .transparent
        displayTarget = try container.decodeIfPresent(
            CompanionDisplayTarget.self,
            forKey: .displayTarget
        ) ?? .followWindow
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        interactionEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .interactionEnabled
        ) ?? true
        sharingPromptEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .sharingPromptEnabled
        ) ?? false
        playbackPreference = try container.decodeIfPresent(
            CompanionPlaybackPreference.self,
            forKey: .playbackPreference
        ) ?? .audiovisual
        reducedDynamicEffectsEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .reducedDynamicEffectsEnabled
        ) ?? false
        remindersEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .remindersEnabled
        ) ?? true
        careCadence = try container.decodeIfPresent(
            CompanionCareCadencePreference.self,
            forKey: .careCadence
        ) ?? .standard
        timeAnnouncementsEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .timeAnnouncementsEnabled
        ) ?? true
        halfHourlyAnnouncementsEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .halfHourlyAnnouncementsEnabled
        ) ?? false
        quietHoursEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .quietHoursEnabled
        ) ?? true
        flirtyRemindersEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .flirtyRemindersEnabled
        ) ?? false
        codexCompletionAnnouncementsEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .codexCompletionAnnouncementsEnabled
        ) ?? true
        usePetName = try container.decodeIfPresent(Bool.self, forKey: .usePetName) ?? false
        randomOutfitsEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .randomOutfitsEnabled
        ) ?? true
        localContentPacksEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .localContentPacksEnabled
        ) ?? true
        learnedGestureIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .learnedGestureIDs
        ) ?? []
    }
}
