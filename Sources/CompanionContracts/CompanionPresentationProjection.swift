import CoreGraphics
import Foundation

public enum CompanionMediaGravity: String, Codable, Equatable, Sendable {
    case aspectFit = "aspect-fit"
    case aspectFill = "aspect-fill"
}

public enum CompanionProjectionRendering: String, Codable, Equatable, Sendable {
    case video
    case staticFallback = "static-fallback"
}

public enum CompanionProjectionSource: String, Codable, Equatable, Sendable {
    case declared
    case declaredTrack = "declared-track"
    case legacyAlias = "legacy-alias"
    case modeDefault = "mode-default"
    case reducedDynamicFallback = "reduced-dynamic-fallback"
}

/// A normalized focal point and zoom supplied by a declarative content pack.
/// `y` is measured from the top of the source frame to match media-authoring
/// tools; Core Animation conversion remains inside this pure contract.
public struct CompanionMediaCropAnchor: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let scale: Double

    public init(x: Double, y: Double, scale: Double) {
        self.x = x
        self.y = y
        self.scale = scale
    }

    public var isValid: Bool {
        x.isFinite && y.isFinite && scale.isFinite
            && (0...1).contains(x)
            && (0...1).contains(y)
            && (1...8).contains(scale)
    }
}

/// One time-addressed crop anchor. Times are relative to the start of the
/// media item; playback looping naturally restarts the track at zero.
public struct CompanionMediaFocalKeyframe: Codable, Equatable, Sendable {
    public let timeMs: Int
    public let x: Double
    public let y: Double
    public let scale: Double

    public init(timeMs: Int, x: Double, y: Double, scale: Double) {
        self.timeMs = timeMs
        self.x = x
        self.y = y
        self.scale = scale
    }

    public var anchor: CompanionMediaCropAnchor {
        CompanionMediaCropAnchor(x: x, y: y, scale: scale)
    }
}

/// A small, deterministic focal timeline. Linear interpolation is deliberate:
/// creator preview, runtime playback and tests can reproduce exactly the same
/// crop without an animation framework or provider-specific easing semantics.
public struct CompanionMediaFocalTrack: Codable, Equatable, Sendable {
    public let keyframes: [CompanionMediaFocalKeyframe]

    public init(keyframes: [CompanionMediaFocalKeyframe]) {
        self.keyframes = keyframes
    }

    public func isValid(durationMs: Int? = nil) -> Bool {
        guard (2...32).contains(keyframes.count),
              keyframes.first?.timeMs == 0 else {
            return false
        }
        var previousTime = -1
        for keyframe in keyframes {
            guard keyframe.timeMs > previousTime,
                  keyframe.anchor.isValid,
                  durationMs.map({ keyframe.timeMs <= $0 }) ?? true else {
                return false
            }
            previousTime = keyframe.timeMs
        }
        return true
    }

    public func anchor(atMilliseconds milliseconds: Double) -> CompanionMediaCropAnchor? {
        guard isValid(), let first = keyframes.first, let last = keyframes.last else {
            return nil
        }
        guard milliseconds.isFinite else { return first.anchor }
        if milliseconds <= Double(first.timeMs) { return first.anchor }
        if milliseconds >= Double(last.timeMs) { return last.anchor }

        guard let upperIndex = keyframes.firstIndex(where: {
            Double($0.timeMs) >= milliseconds
        }), upperIndex > 0 else {
            return first.anchor
        }
        let lower = keyframes[upperIndex - 1]
        let upper = keyframes[upperIndex]
        let span = Double(upper.timeMs - lower.timeMs)
        let progress = (milliseconds - Double(lower.timeMs)) / span
        return CompanionMediaCropAnchor(
            x: lower.x + ((upper.x - lower.x) * progress),
            y: lower.y + ((upper.y - lower.y) * progress),
            scale: lower.scale + ((upper.scale - lower.scale) * progress)
        )
    }
}

/// A normalized source-frame region that an author expects to remain visible.
/// Coordinates use the same top-left origin as crop anchors and author tools.
public struct CompanionMediaSafeArea: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isValid: Bool {
        x.isFinite && y.isFinite && width.isFinite && height.isFinite
            && x >= 0 && y >= 0 && width > 0 && height > 0
            && x + width <= 1 && y + height <= 1
    }

    /// Uses the same bounded normalized crop as `playerLayerFrame`. This is a
    /// conservative authoring guarantee, not a claim about screen safe areas.
    public func isVisible(through anchor: CompanionMediaCropAnchor) -> Bool {
        guard isValid, anchor.isValid else { return false }
        let visibleExtent = 1 / anchor.scale
        let maximumOrigin = 1 - visibleExtent
        let visibleX = min(max(anchor.x - (visibleExtent / 2), 0), maximumOrigin)
        let visibleY = min(max(anchor.y - (visibleExtent / 2), 0), maximumOrigin)
        let epsilon = 0.000_001
        return x + epsilon >= visibleX
            && y + epsilon >= visibleY
            && x + width <= visibleX + visibleExtent + epsilon
            && y + height <= visibleY + visibleExtent + epsilon
    }
}

/// The complete, platform-neutral decision used to project one landscape
/// master video into pet, stage and fullscreen presentations.
public struct CompanionPresentationProjection: Equatable, Sendable {
    public let mode: CompanionPresentationMode
    public let rendering: CompanionProjectionRendering
    public let gravity: CompanionMediaGravity
    public let anchor: CompanionMediaCropAnchor?
    public let focalTrack: CompanionMediaFocalTrack?
    public let safeArea: CompanionMediaSafeArea?
    public let source: CompanionProjectionSource
    public let resolvedAnchorKey: String?
    public let resolvedSafeAreaKey: String?

    public init(
        mode: CompanionPresentationMode,
        rendering: CompanionProjectionRendering,
        gravity: CompanionMediaGravity,
        anchor: CompanionMediaCropAnchor?,
        focalTrack: CompanionMediaFocalTrack? = nil,
        safeArea: CompanionMediaSafeArea? = nil,
        source: CompanionProjectionSource,
        resolvedAnchorKey: String?,
        resolvedSafeAreaKey: String? = nil
    ) {
        self.mode = mode
        self.rendering = rendering
        self.gravity = gravity
        self.anchor = anchor
        self.focalTrack = focalTrack
        self.safeArea = safeArea
        self.source = source
        self.resolvedAnchorKey = resolvedAnchorKey
        self.resolvedSafeAreaKey = resolvedSafeAreaKey
    }

    public var permitsVideo: Bool {
        rendering == .video
    }

    public var hasDynamicFocalTrack: Bool {
        focalTrack != nil
    }

    public func resolvedAnchor(atMilliseconds milliseconds: Double) -> CompanionMediaCropAnchor? {
        focalTrack?.anchor(atMilliseconds: milliseconds) ?? anchor
    }

    /// Returns the player-layer frame needed to keep the declared focal point
    /// at the centre of the visible viewport. Invalid geometry never escapes
    /// into AppKit; it degrades to the unmodified viewport.
    public func playerLayerFrame(
        in viewport: CGRect,
        atMilliseconds milliseconds: Double = 0
    ) -> CGRect {
        guard viewport.origin.x.isFinite,
              viewport.origin.y.isFinite,
              viewport.width.isFinite,
              viewport.height.isFinite,
              viewport.width > 0,
              viewport.height > 0,
              let anchor = resolvedAnchor(atMilliseconds: milliseconds),
              anchor.isValid else {
            return viewport
        }

        let width = viewport.width * anchor.scale
        let height = viewport.height * anchor.scale
        let desiredX = viewport.midX - (CGFloat(anchor.x) * width)
        let desiredY = viewport.midY - (CGFloat(1 - anchor.y) * height)
        let boundedX = min(max(desiredX, viewport.maxX - width), viewport.minX)
        let boundedY = min(max(desiredY, viewport.maxY - height), viewport.minY)
        return CGRect(
            x: boundedX,
            y: boundedY,
            width: width,
            height: height
        )
    }

    public static func resolve(
        mode: CompanionPresentationMode,
        cropAnchors: [String: CompanionMediaCropAnchor],
        focalTracks: [String: CompanionMediaFocalTrack] = [:],
        safeAreas: [String: CompanionMediaSafeArea] = [:],
        reducedDynamicEffectsEnabled: Bool
    ) -> CompanionPresentationProjection {
        guard !reducedDynamicEffectsEnabled else {
            return CompanionPresentationProjection(
                mode: mode,
                rendering: .staticFallback,
                gravity: .aspectFit,
                anchor: nil,
                focalTrack: nil,
                safeArea: nil,
                source: .reducedDynamicFallback,
                resolvedAnchorKey: nil,
                resolvedSafeAreaKey: nil
            )
        }

        let keys: [String]
        switch mode {
        case .pet:
            keys = ["pet"]
        case .stage:
            keys = ["stage", "partial"]
        case .fullscreen:
            keys = ["fullscreen", "full"]
        }

        let resolvedSafeArea = keys.lazy.compactMap { key -> (String, CompanionMediaSafeArea)? in
            guard let value = safeAreas[key], value.isValid else { return nil }
            return (key, value)
        }.first

        for (index, key) in keys.enumerated() {
            if let track = focalTracks[key], track.isValid(),
               let initialAnchor = track.anchor(atMilliseconds: 0) {
                return CompanionPresentationProjection(
                    mode: mode,
                    rendering: .video,
                    gravity: .aspectFit,
                    anchor: initialAnchor,
                    focalTrack: track,
                    safeArea: resolvedSafeArea?.1,
                    source: index == 0 ? .declaredTrack : .legacyAlias,
                    resolvedAnchorKey: key,
                    resolvedSafeAreaKey: resolvedSafeArea?.0
                )
            }
            guard let anchor = cropAnchors[key], anchor.isValid else {
                continue
            }
            return CompanionPresentationProjection(
                mode: mode,
                rendering: .video,
                gravity: .aspectFit,
                anchor: anchor,
                focalTrack: nil,
                safeArea: resolvedSafeArea?.1,
                source: index == 0 ? .declared : .legacyAlias,
                resolvedAnchorKey: key,
                resolvedSafeAreaKey: resolvedSafeArea?.0
            )
        }

        return CompanionPresentationProjection(
            mode: mode,
            rendering: .video,
            gravity: mode == .pet ? .aspectFill : .aspectFit,
            anchor: nil,
            focalTrack: nil,
            safeArea: nil,
            source: .modeDefault,
            resolvedAnchorKey: nil,
            resolvedSafeAreaKey: nil
        )
    }
}
