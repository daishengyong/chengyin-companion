import CoreGraphics
import Foundation

public struct CompanionPresentationSurfacePlan: Equatable, Sendable {
    public let requestedAppearance: CompanionPresentationAppearance
    public let resolvedAppearance: CompanionPresentationAppearance
    public let backgroundOpacity: Double
    public let vignetteOpacity: Double
    public let usesTranslucentMaterial: Bool
    public let showsWindowShadow: Bool
    public let cornerRadius: Double

    public init(
        requestedAppearance: CompanionPresentationAppearance,
        resolvedAppearance: CompanionPresentationAppearance,
        backgroundOpacity: Double,
        vignetteOpacity: Double,
        usesTranslucentMaterial: Bool,
        showsWindowShadow: Bool,
        cornerRadius: Double
    ) {
        self.requestedAppearance = requestedAppearance
        self.resolvedAppearance = resolvedAppearance
        self.backgroundOpacity = backgroundOpacity
        self.vignetteOpacity = vignetteOpacity
        self.usesTranslucentMaterial = usesTranslucentMaterial
        self.showsWindowShadow = showsWindowShadow
        self.cornerRadius = cornerRadius
    }
}

/// Pure appearance policy. AppKit and SwiftUI render the returned values; Core
/// owns accessibility fallback and presentation-mode consistency.
public enum CompanionPresentationSurfacePolicy {
    public static func plan(
        mode: CompanionPresentationMode,
        requestedAppearance: CompanionPresentationAppearance,
        systemReduceTransparencyEnabled: Bool,
        systemIncreaseContrastEnabled: Bool
    ) -> CompanionPresentationSurfacePlan {
        let resolved: CompanionPresentationAppearance =
            requestedAppearance == .cinematic && systemReduceTransparencyEnabled
                ? .dim
                : requestedAppearance
        let contrastBoost = systemIncreaseContrastEnabled ? 0.14 : 0
        let radius: Double
        switch mode {
        case .pet: radius = 26
        case .stage: radius = 30
        case .fullscreen: radius = 0
        }

        switch resolved {
        case .transparent:
            return CompanionPresentationSurfacePlan(
                requestedAppearance: requestedAppearance,
                resolvedAppearance: resolved,
                backgroundOpacity: 0,
                vignetteOpacity: 0,
                usesTranslucentMaterial: false,
                showsWindowShadow: mode != .pet,
                cornerRadius: radius
            )
        case .cinematic:
            return CompanionPresentationSurfacePlan(
                requestedAppearance: requestedAppearance,
                resolvedAppearance: resolved,
                backgroundOpacity: min(0.86, 0.64 + contrastBoost),
                vignetteOpacity: min(0.52, 0.28 + contrastBoost),
                usesTranslucentMaterial: true,
                showsWindowShadow: true,
                cornerRadius: radius
            )
        case .dim:
            return CompanionPresentationSurfacePlan(
                requestedAppearance: requestedAppearance,
                resolvedAppearance: resolved,
                backgroundOpacity: min(0.82, 0.52 + contrastBoost),
                vignetteOpacity: min(0.44, 0.22 + contrastBoost),
                usesTranslucentMaterial: false,
                showsWindowShadow: true,
                cornerRadius: radius
            )
        }
    }
}

public struct CompanionDisplayDescriptor: Equatable, Sendable {
    public let identifier: String
    public let visibleFrame: CGRect
    public let isMain: Bool

    public init(identifier: String, visibleFrame: CGRect, isMain: Bool) {
        self.identifier = identifier
        self.visibleFrame = visibleFrame
        self.isMain = isMain
    }

    public var isValid: Bool {
        CompanionDisplayTarget.isValidIdentifier(identifier)
            && visibleFrame.origin.x.isFinite
            && visibleFrame.origin.y.isFinite
            && visibleFrame.width.isFinite
            && visibleFrame.height.isFinite
            && visibleFrame.width > 0
            && visibleFrame.height > 0
    }
}

public enum CompanionDisplayResolution: String, Codable, Equatable, Sendable {
    case followedCurrent = "followed-current"
    case selectedMain = "selected-main"
    case selectedSpecific = "selected-specific"
    case recoveredToCurrent = "recovered-to-current"
    case recoveredToMain = "recovered-to-main"
    case recoveredToFirst = "recovered-to-first"
    case usedFallback = "used-fallback"
}

public struct CompanionDisplaySelection: Equatable, Sendable {
    public let descriptor: CompanionDisplayDescriptor
    public let resolution: CompanionDisplayResolution

    public init(
        descriptor: CompanionDisplayDescriptor,
        resolution: CompanionDisplayResolution
    ) {
        self.descriptor = descriptor
        self.resolution = resolution
    }
}

/// Selects a visible frame from privacy-minimal display facts. Missing or
/// invalid displays always recover deterministically instead of preserving an
/// off-screen frame from a disconnected monitor.
public enum CompanionDisplaySelectionPolicy {
    public static func resolve(
        target: CompanionDisplayTarget,
        currentDisplayIdentifier: String?,
        displays: [CompanionDisplayDescriptor]
    ) -> CompanionDisplaySelection {
        let valid = displays.filter(\.isValid)
        let current = currentDisplayIdentifier.flatMap { identifier in
            valid.first { $0.identifier == identifier }
        }
        let main = valid.first(where: \.isMain)
        let first = valid.sorted { $0.identifier < $1.identifier }.first

        if target.isValid {
            switch target.mode {
            case .followWindow:
                if let current {
                    return CompanionDisplaySelection(
                        descriptor: current,
                        resolution: .followedCurrent
                    )
                }
            case .main:
                if let main {
                    return CompanionDisplaySelection(
                        descriptor: main,
                        resolution: .selectedMain
                    )
                }
            case .specific:
                if let identifier = target.identifier,
                   let selected = valid.first(where: { $0.identifier == identifier }) {
                    return CompanionDisplaySelection(
                        descriptor: selected,
                        resolution: .selectedSpecific
                    )
                }
            }
        }

        if let current {
            return CompanionDisplaySelection(
                descriptor: current,
                resolution: .recoveredToCurrent
            )
        }
        if let main {
            return CompanionDisplaySelection(
                descriptor: main,
                resolution: .recoveredToMain
            )
        }
        if let first {
            return CompanionDisplaySelection(
                descriptor: first,
                resolution: .recoveredToFirst
            )
        }
        return CompanionDisplaySelection(
            descriptor: CompanionDisplayDescriptor(
                identifier: "fallback-display",
                visibleFrame: CompanionWindowPolicy.fallbackVisibleFrame,
                isMain: true
            ),
            resolution: .usedFallback
        )
    }
}
