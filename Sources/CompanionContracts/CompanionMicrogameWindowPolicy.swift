import CoreGraphics

/// A deterministic, side-effect-free window placement returned to AppKit.
/// `edge` is present only when the hide-and-seek pet is intentionally peeking
/// from that edge of the selected display.
public struct CompanionMicrogameWindowPlacement: Equatable, Sendable {
    public let origin: CGPoint
    public let edge: CompanionWindowDockEdge?

    public init(
        origin: CGPoint,
        edge: CompanionWindowDockEdge? = nil
    ) {
        self.origin = origin
        self.edge = edge
    }
}

/// Pure geometry for the existing catch and hide-and-seek games.
///
/// AppKit supplies only the selected display's visible frame, the decorated
/// pet-window size, pointer location and opaque entropy. The policy never
/// reads global screens, pointer state or saved user data. It keeps catch
/// targets fully reachable, preserves a clickable strip for every hidden
/// edge, avoids immediately repeating the same hide edge and recovers from
/// non-finite or unusable geometry without escaping to another display.
public enum CompanionMicrogameWindowPolicy {
    public static let catchEdgeInset: CGFloat = 24
    public static let catchPointerClearance: CGFloat = 210
    public static let horizontalPeekExtent: CGFloat = 48
    public static let verticalPeekExtent: CGFloat = 112

    public static func catchPlacement(
        visibleFrame: CGRect,
        windowFrameSize: CGSize,
        pointerLocation: CGPoint,
        entropy: UInt64
    ) -> CompanionMicrogameWindowPlacement {
        let visible = normalizedVisibleFrame(visibleFrame)
        let size = normalizedWindowSize(windowFrameSize)
        let pointer = normalizedPointer(pointerLocation, in: visible)
        let candidates = gridOrigins(
            visibleFrame: visible,
            windowFrameSize: size,
            horizontalInset: catchEdgeInset,
            verticalInset: catchEdgeInset
        )
        let eligible = candidates.filter {
            distance(
                from: CGPoint(
                    x: $0.x + (size.width / 2),
                    y: $0.y + (size.height / 2)
                ),
                to: pointer
            ) > catchPointerClearance
        }
        let pool = eligible.isEmpty ? candidates : eligible
        let origin = pool.isEmpty
            ? CompanionWindowPolicy.initialOrigin(
                for: .pet,
                visibleFrame: visible,
                windowFrameSize: size,
                savedPetOrigin: nil
            )
            : pool[boundedIndex(entropy, count: pool.count)]
        return CompanionMicrogameWindowPlacement(origin: origin)
    }

    public static func hidePlacement(
        visibleFrame: CGRect,
        windowFrameSize: CGSize,
        previousEdge: CompanionWindowDockEdge?,
        entropy: UInt64
    ) -> CompanionMicrogameWindowPlacement {
        let visible = normalizedVisibleFrame(visibleFrame)
        let size = normalizedWindowSize(windowFrameSize)
        let edges = CompanionWindowDockEdge.allCases.filter {
            $0 != previousEdge
        }
        let edge = edges[boundedIndex(entropy, count: edges.count)]
        let slotEntropy = entropy / UInt64(max(1, edges.count))
        let horizontalSlots = axisOrigins(
            minimum: visible.minX,
            maximum: visible.maxX,
            extent: size.width,
            inset: 90
        )
        let verticalSlots = axisOrigins(
            minimum: visible.minY,
            maximum: visible.maxY,
            extent: size.height,
            inset: 70
        )
        let x = horizontalSlots[
            boundedIndex(slotEntropy, count: horizontalSlots.count)
        ]
        let y = verticalSlots[
            boundedIndex(slotEntropy, count: verticalSlots.count)
        ]
        let horizontalPeek = min(horizontalPeekExtent, size.width)
        let verticalPeek = min(verticalPeekExtent, size.height)

        let origin: CGPoint
        switch edge {
        case .left:
            origin = CGPoint(
                x: visible.minX - size.width + horizontalPeek,
                y: y
            )
        case .right:
            origin = CGPoint(
                x: visible.maxX - horizontalPeek,
                y: y
            )
        case .top:
            origin = CGPoint(
                x: x,
                y: visible.maxY - verticalPeek
            )
        case .bottom:
            origin = CGPoint(
                x: x,
                y: visible.minY - size.height + verticalPeek
            )
        }
        return CompanionMicrogameWindowPlacement(origin: origin, edge: edge)
    }

    private static func gridOrigins(
        visibleFrame: CGRect,
        windowFrameSize: CGSize,
        horizontalInset: CGFloat,
        verticalInset: CGFloat
    ) -> [CGPoint] {
        let xs = axisOrigins(
            minimum: visibleFrame.minX,
            maximum: visibleFrame.maxX,
            extent: windowFrameSize.width,
            inset: horizontalInset
        )
        let ys = axisOrigins(
            minimum: visibleFrame.minY,
            maximum: visibleFrame.maxY,
            extent: windowFrameSize.height,
            inset: verticalInset
        )
        var result: [CGPoint] = []
        for x in xs {
            for y in ys {
                let point = CGPoint(x: x, y: y)
                if !result.contains(point) {
                    result.append(point)
                }
            }
        }
        return result
    }

    private static func axisOrigins(
        minimum: CGFloat,
        maximum: CGFloat,
        extent: CGFloat,
        inset: CGFloat
    ) -> [CGFloat] {
        let available = maximum - minimum
        guard extent + (inset * 2) <= available else {
            return [minimum]
        }
        let candidates = [
            minimum + inset,
            minimum + ((available - extent) / 2),
            maximum - extent - inset
        ]
        var result: [CGFloat] = []
        for candidate in candidates where !result.contains(candidate) {
            result.append(candidate)
        }
        return result
    }

    private static func normalizedVisibleFrame(_ frame: CGRect) -> CGRect {
        guard frame.origin.x.isFinite,
              frame.origin.y.isFinite,
              frame.width.isFinite,
              frame.height.isFinite,
              frame.width > 0,
              frame.height > 0 else {
            return CompanionWindowPolicy.fallbackVisibleFrame
        }
        return frame.standardized
    }

    private static func normalizedWindowSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: size.width.isFinite ? max(0, size.width) : 0,
            height: size.height.isFinite ? max(0, size.height) : 0
        )
    }

    private static func normalizedPointer(
        _ pointer: CGPoint,
        in visibleFrame: CGRect
    ) -> CGPoint {
        guard pointer.x.isFinite, pointer.y.isFinite else {
            return CGPoint(x: visibleFrame.midX, y: visibleFrame.midY)
        }
        return pointer
    }

    private static func boundedIndex(_ entropy: UInt64, count: Int) -> Int {
        guard count > 1 else { return 0 }
        return Int(entropy % UInt64(count))
    }

    private static func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
