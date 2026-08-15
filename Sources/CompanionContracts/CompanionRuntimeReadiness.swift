import Foundation

public enum CompanionRuntimeReadinessComponent: String, CaseIterable, Sendable {
    case appIdentity
    case starterMedia
    case starterContract
    case eventBridge
    case contentLibrary
    case privacyBoundary
}

public enum CompanionRuntimeReadinessLevel: String, Sendable {
    case ready
    case paused
    case attention
}

/// The only runtime repairs that are safe to attempt without replacing app
/// binaries, deleting user content, enabling a preference, or contacting a
/// network service. Other attention states remain explicit manual gates.
public enum CompanionRuntimeRecoveryAction: String, Equatable, Sendable {
    case repairEventBridge
    case recoverContentLibrary
}

public struct CompanionRuntimeReadinessFacts: Equatable, Sendable {
    public var hasBuildIdentity: Bool
    public var bundledVideoCount: Int
    public var declaredVoiceLineCount: Int
    public var availableVoiceLineCount: Int
    public var starterContractPresent: Bool
    public var starterPublicDistributionReady: Bool
    public var eventBridgeReady: Bool
    public var localContentPacksEnabled: Bool
    public var contentLibraryHealthy: Bool
    public var microphoneUsageDeclared: Bool

    public init(
        hasBuildIdentity: Bool,
        bundledVideoCount: Int,
        declaredVoiceLineCount: Int,
        availableVoiceLineCount: Int,
        starterContractPresent: Bool,
        starterPublicDistributionReady: Bool,
        eventBridgeReady: Bool,
        localContentPacksEnabled: Bool,
        contentLibraryHealthy: Bool = true,
        microphoneUsageDeclared: Bool
    ) {
        self.hasBuildIdentity = hasBuildIdentity
        self.bundledVideoCount = max(0, bundledVideoCount)
        self.declaredVoiceLineCount = max(0, declaredVoiceLineCount)
        self.availableVoiceLineCount = max(0, availableVoiceLineCount)
        self.starterContractPresent = starterContractPresent
        self.starterPublicDistributionReady = starterPublicDistributionReady
        self.eventBridgeReady = eventBridgeReady
        self.localContentPacksEnabled = localContentPacksEnabled
        self.contentLibraryHealthy = contentLibraryHealthy
        self.microphoneUsageDeclared = microphoneUsageDeclared
    }
}

public struct CompanionRuntimeReadinessCheck: Equatable, Sendable {
    public let component: CompanionRuntimeReadinessComponent
    public let level: CompanionRuntimeReadinessLevel

    public init(
        component: CompanionRuntimeReadinessComponent,
        level: CompanionRuntimeReadinessLevel
    ) {
        self.component = component
        self.level = level
    }
}

public enum CompanionRuntimeReadiness {
    public static func evaluate(
        _ facts: CompanionRuntimeReadinessFacts
    ) -> [CompanionRuntimeReadinessCheck] {
        [
            CompanionRuntimeReadinessCheck(
                component: .appIdentity,
                level: facts.hasBuildIdentity ? .ready : .attention
            ),
            CompanionRuntimeReadinessCheck(
                component: .starterMedia,
                level: facts.bundledVideoCount > 0
                    && facts.declaredVoiceLineCount > 0
                    && facts.availableVoiceLineCount == facts.declaredVoiceLineCount
                    ? .ready
                    : .attention
            ),
            CompanionRuntimeReadinessCheck(
                component: .starterContract,
                level: !facts.starterContractPresent
                    ? .attention
                    : facts.starterPublicDistributionReady ? .ready : .paused
            ),
            CompanionRuntimeReadinessCheck(
                component: .eventBridge,
                level: facts.eventBridgeReady ? .ready : .attention
            ),
            CompanionRuntimeReadinessCheck(
                component: .contentLibrary,
                level: !facts.contentLibraryHealthy
                    ? .attention
                    : facts.localContentPacksEnabled ? .ready : .paused
            ),
            CompanionRuntimeReadinessCheck(
                component: .privacyBoundary,
                level: facts.microphoneUsageDeclared ? .attention : .ready
            )
        ]
    }

    public static func needsAttention(
        _ checks: [CompanionRuntimeReadinessCheck]
    ) -> Bool {
        checks.contains { $0.level == .attention }
    }

    public static func safeRecoveryActions(
        _ checks: [CompanionRuntimeReadinessCheck]
    ) -> [CompanionRuntimeRecoveryAction] {
        let attention = Set(
            checks.lazy
                .filter { $0.level == .attention }
                .map(\.component)
        )
        var actions: [CompanionRuntimeRecoveryAction] = []
        if attention.contains(.eventBridge) {
            actions.append(.repairEventBridge)
        }
        if attention.contains(.contentLibrary) {
            actions.append(.recoverContentLibrary)
        }
        return actions
    }

    /// Attention may include missing app/media identity or an unexpected
    /// permission declaration. Those states must never be hidden behind a
    /// successful local repair receipt.
    public static func hasManualAttention(
        _ checks: [CompanionRuntimeReadinessCheck]
    ) -> Bool {
        let recoverable: Set<CompanionRuntimeReadinessComponent> = [
            .eventBridge,
            .contentLibrary
        ]
        return checks.contains {
            $0.level == .attention && !recoverable.contains($0.component)
        }
    }
}
