import Foundation
import CoreGraphics

public enum CompanionWindowDockEdge: String, Codable, CaseIterable, Equatable, Sendable {
    case left
    case right
    case top
    case bottom
}

public struct CompanionWindowDockResult: Equatable, Sendable {
    public let origin: CGPoint
    public let edge: CompanionWindowDockEdge?

    public init(origin: CGPoint, edge: CompanionWindowDockEdge?) {
        self.origin = origin
        self.edge = edge
    }

    public static func == (
        lhs: CompanionWindowDockResult,
        rhs: CompanionWindowDockResult
    ) -> Bool {
        lhs.origin.x == rhs.origin.x
            && lhs.origin.y == rhs.origin.y
            && lhs.edge == rhs.edge
    }
}

/// Pure placement contract shared by launch, presentation changes and drag
/// completion. AppKit still converts content size to a decorated frame size;
/// every policy decision after that conversion lives here so it can be tested
/// without launching a window server.
public enum CompanionWindowPolicy {
    public static let fallbackVisibleFrame = CGRect(
        x: 0,
        y: 0,
        width: 1_440,
        height: 900
    )

    public static func contentSize(
        for mode: CompanionPresentationMode,
        visibleFrame: CGRect
    ) -> CGSize {
        switch mode {
        case .pet:
            CGSize(width: 132, height: 146)
        case .stage:
            CGSize(width: 560, height: 520)
        case .fullscreen:
            normalizedVisibleFrame(visibleFrame).size
        }
    }

    /// A head-mode play palette owns a larger, upward-opening window than the
    /// pet itself. Keeping this geometry in the shared policy prevents the
    /// SwiftUI root and AppKit window configurator from disagreeing and
    /// clipping the bottom rows into a scroll-only system-menu experience.
    public static func playPaletteContentSize(
        visibleFrame: CGRect
    ) -> CGSize {
        CompanionPlayPaletteLayout.plan(
            visibleFrame: visibleFrame
        ).contentSize
    }

    /// Returns a corrective frame only when the live AppKit panel is still at
    /// the wrong size after a presentation-state change. This is deliberately
    /// separate from the normal animated placement path: callers can wait for
    /// their UI transition, compare the resulting frame, and repair a dropped
    /// resize without continuously fighting legitimate window movement.
    public static func geometryRecoveryFrame(
        currentFrame: CGRect,
        targetFrameSize: CGSize,
        mode: CompanionPresentationMode,
        visibleFrame: CGRect,
        tolerance: CGFloat = 1
    ) -> CGRect? {
        let visible = normalizedVisibleFrame(visibleFrame)
        let targetSize = normalizedWindowSize(targetFrameSize)
        let safeTolerance = finiteNonnegative(tolerance)
        guard abs(currentFrame.width - targetSize.width) > safeTolerance
                || abs(currentFrame.height - targetSize.height) > safeTolerance
        else {
            return nil
        }

        if mode == .fullscreen {
            return CGRect(origin: visible.origin, size: targetSize)
        }

        let safeCurrent = CGRect(
            x: currentFrame.origin.x.isFinite
                ? currentFrame.origin.x
                : visible.minX,
            y: currentFrame.origin.y.isFinite
                ? currentFrame.origin.y
                : visible.minY,
            width: currentFrame.width.isFinite
                ? max(0, currentFrame.width)
                : 0,
            height: currentFrame.height.isFinite
                ? max(0, currentFrame.height)
                : 0
        )
        let origin = CGPoint(
            x: min(
                visible.maxX - targetSize.width,
                max(visible.minX, safeCurrent.maxX - targetSize.width)
            ),
            y: min(
                visible.maxY - targetSize.height,
                max(visible.minY, safeCurrent.minY)
            )
        )
        return CGRect(origin: origin, size: targetSize)
    }

    public static func isPetPresentation(_ mode: CompanionPresentationMode) -> Bool {
        mode != .fullscreen
    }

    public static func initialOrigin(
        for mode: CompanionPresentationMode,
        visibleFrame: CGRect,
        windowFrameSize: CGSize,
        savedPetOrigin: CGPoint?
    ) -> CGPoint {
        let visible = normalizedVisibleFrame(visibleFrame)
        guard isPetPresentation(mode) else { return visible.origin }

        let frameSize = normalizedWindowSize(windowFrameSize)
        let fallback = CGPoint(
            x: visible.maxX - frameSize.width - 24,
            y: visible.minY + 24
        )
        return clampedPetOrigin(
            savedPetOrigin ?? fallback,
            visibleFrame: visible,
            windowFrameSize: frameSize
        )
    }

    public static func clampedPetOrigin(
        _ candidate: CGPoint,
        visibleFrame: CGRect,
        windowFrameSize: CGSize,
        edgeInset: CGFloat = 8
    ) -> CGPoint {
        let visible = normalizedVisibleFrame(visibleFrame)
        let size = normalizedWindowSize(windowFrameSize)
        let inset = finiteNonnegative(edgeInset)
        let safeCandidate = CGPoint(
            x: candidate.x.isFinite ? candidate.x : visible.minX,
            y: candidate.y.isFinite ? candidate.y : visible.minY
        )

        return CGPoint(
            x: clampedCoordinate(
                safeCandidate.x,
                minimum: visible.minX,
                maximum: visible.maxX,
                extent: size.width,
                inset: inset
            ),
            y: clampedCoordinate(
                safeCandidate.y,
                minimum: visible.minY,
                maximum: visible.maxY,
                extent: size.height,
                inset: inset
            )
        )
    }

    public static func dockedPetOrigin(
        _ candidate: CGPoint,
        visibleFrame: CGRect,
        windowFrameSize: CGSize,
        snapThreshold: CGFloat = 58,
        edgeInset: CGFloat = 8
    ) -> CompanionWindowDockResult {
        let visible = normalizedVisibleFrame(visibleFrame)
        let size = normalizedWindowSize(windowFrameSize)
        let threshold = finiteNonnegative(snapThreshold)
        let candidateFrame = CGRect(origin: candidate, size: size)
        let distances: [(CompanionWindowDockEdge, CGFloat)] = [
            (.left, abs(candidateFrame.minX - visible.minX)),
            (.right, abs(visible.maxX - candidateFrame.maxX)),
            (.bottom, abs(candidateFrame.minY - visible.minY)),
            (.top, abs(visible.maxY - candidateFrame.maxY))
        ]
        let nearest = distances.min { $0.1 < $1.1 }
        let edge = nearest.flatMap { $0.1.isFinite && $0.1 <= threshold ? $0.0 : nil }

        var snapped = candidate
        switch edge {
        case .left:
            snapped.x = visible.minX + finiteNonnegative(edgeInset)
        case .right:
            snapped.x = visible.maxX - size.width - finiteNonnegative(edgeInset)
        case .bottom:
            snapped.y = visible.minY + finiteNonnegative(edgeInset)
        case .top:
            snapped.y = visible.maxY - size.height - finiteNonnegative(edgeInset)
        case nil:
            break
        }

        return CompanionWindowDockResult(
            origin: clampedPetOrigin(
                snapped,
                visibleFrame: visible,
                windowFrameSize: size,
                edgeInset: edgeInset
            ),
            edge: edge
        )
    }

    private static func normalizedVisibleFrame(_ frame: CGRect) -> CGRect {
        guard
            frame.origin.x.isFinite,
            frame.origin.y.isFinite,
            frame.width.isFinite,
            frame.height.isFinite,
            frame.width > 0,
            frame.height > 0
        else {
            return fallbackVisibleFrame
        }
        return frame.standardized
    }

    private static func normalizedWindowSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: finiteNonnegative(size.width),
            height: finiteNonnegative(size.height)
        )
    }

    private static func finiteNonnegative(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(0, value) : 0
    }

    private static func clampedCoordinate(
        _ value: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat,
        extent: CGFloat,
        inset: CGFloat
    ) -> CGFloat {
        let span = maximum - minimum
        guard extent + (inset * 2) <= span else {
            return minimum
        }
        return max(minimum + inset, min(value, maximum - extent - inset))
    }
}
