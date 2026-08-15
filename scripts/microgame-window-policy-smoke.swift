import CoreGraphics
import Foundation

private enum SmokeFailure: Error {
    case failed(String)
}

private func approximatelyEqual(
    _ lhs: CGFloat,
    _ rhs: CGFloat,
    tolerance: CGFloat = 0.001
) -> Bool {
    abs(lhs - rhs) <= tolerance
}

@main
struct CompanionMicrogameWindowPolicySmoke {
    static func main() throws {
        var checks = 0
        func require(
            _ condition: @autoclosure () -> Bool,
            _ message: String
        ) throws {
            guard condition() else { throw SmokeFailure.failed(message) }
            checks += 1
        }

        let visible = CGRect(x: -1_680, y: 72, width: 1_680, height: 978)
        let size = CGSize(width: 132, height: 146)
        let pointer = CGPoint(x: -840, y: 561)

        let catchA = CompanionMicrogameWindowPolicy.catchPlacement(
            visibleFrame: visible,
            windowFrameSize: size,
            pointerLocation: pointer,
            entropy: 7
        )
        let catchB = CompanionMicrogameWindowPolicy.catchPlacement(
            visibleFrame: visible,
            windowFrameSize: size,
            pointerLocation: pointer,
            entropy: 7
        )
        try require(catchA == catchB, "catch placement is not deterministic")

        let catchFrame = CGRect(origin: catchA.origin, size: size)
        try require(
            visible.contains(catchFrame),
            "catch target escaped the selected display"
        )
        let catchCenter = CGPoint(x: catchFrame.midX, y: catchFrame.midY)
        try require(
            hypot(catchCenter.x - pointer.x, catchCenter.y - pointer.y)
                > CompanionMicrogameWindowPolicy.catchPointerClearance,
            "catch target remained under the pointer"
        )

        let catchOrigins = Set((0..<24).map {
            CompanionMicrogameWindowPolicy.catchPlacement(
                visibleFrame: visible,
                windowFrameSize: size,
                pointerLocation: pointer,
                entropy: UInt64($0)
            ).origin.debugDescription
        })
        try require(catchOrigins.count >= 4, "catch entropy did not vary targets")
        try require(catchA.origin.x < 0, "catch placement leaked to the main display")

        let invalidCatch = CompanionMicrogameWindowPolicy.catchPlacement(
            visibleFrame: CGRect(
                x: CGFloat.nan,
                y: 0,
                width: 0,
                height: CGFloat.infinity
            ),
            windowFrameSize: CGSize(
                width: CGFloat.infinity,
                height: CGFloat.nan
            ),
            pointerLocation: CGPoint(
                x: CGFloat.nan,
                y: CGFloat.infinity
            ),
            entropy: 0
        )
        try require(
            invalidCatch.origin.x.isFinite && invalidCatch.origin.y.isFinite,
            "invalid catch geometry did not recover to finite coordinates"
        )

        let oversizedCatch = CompanionMicrogameWindowPolicy.catchPlacement(
            visibleFrame: CGRect(x: 30, y: 40, width: 100, height: 90),
            windowFrameSize: CGSize(width: 180, height: 160),
            pointerLocation: CGPoint(x: 80, y: 85),
            entropy: UInt64.max
        )
        try require(
            oversizedCatch.origin == CGPoint(x: 30, y: 40),
            "oversized catch target did not use the selected display origin"
        )

        let hideSequence = (0..<4).map {
            CompanionMicrogameWindowPolicy.hidePlacement(
                visibleFrame: visible,
                windowFrameSize: size,
                previousEdge: nil,
                entropy: UInt64($0)
            )
        }
        try require(
            Set(hideSequence.compactMap(\.edge)).count == 4,
            "hide entropy did not cover every edge"
        )
        let deterministicHide = CompanionMicrogameWindowPolicy.hidePlacement(
            visibleFrame: visible,
            windowFrameSize: size,
            previousEdge: .left,
            entropy: 9
        )
        try require(
            deterministicHide == CompanionMicrogameWindowPolicy.hidePlacement(
                visibleFrame: visible,
                windowFrameSize: size,
                previousEdge: .left,
                entropy: 9
            ),
            "hide placement is not deterministic"
        )
        try require(
            (0..<32).allSatisfy {
                CompanionMicrogameWindowPolicy.hidePlacement(
                    visibleFrame: visible,
                    windowFrameSize: size,
                    previousEdge: .top,
                    entropy: UInt64($0)
                ).edge != .top
            },
            "hide placement repeated the immediately previous edge"
        )

        for placement in hideSequence {
            guard let edge = placement.edge else {
                throw SmokeFailure.failed("hide placement lost its edge")
            }
            let frame = CGRect(origin: placement.origin, size: size)
            let intersection = frame.intersection(visible)
            try require(
                !intersection.isNull && intersection.width > 0 && intersection.height > 0,
                "hidden pet became completely unreachable"
            )
            switch edge {
            case .left, .right:
                try require(
                    approximatelyEqual(
                        intersection.width,
                        CompanionMicrogameWindowPolicy.horizontalPeekExtent
                    ),
                    "horizontal edge lost its clickable peek width"
                )
                try require(
                    intersection.height == size.height,
                    "horizontal hide clipped the pet on the orthogonal axis"
                )
            case .top, .bottom:
                try require(
                    approximatelyEqual(
                        intersection.height,
                        CompanionMicrogameWindowPolicy.verticalPeekExtent
                    ),
                    "vertical edge lost its clickable peek height"
                )
                try require(
                    intersection.width == size.width,
                    "vertical hide clipped the pet on the orthogonal axis"
                )
            }
            try require(
                intersection.minX >= visible.minX
                    && intersection.maxX <= visible.maxX
                    && intersection.minY >= visible.minY
                    && intersection.maxY <= visible.maxY,
                "hide placement crossed the selected display coordinate space"
            )
        }

        let tinyPet = CGSize(width: 30, height: 40)
        let tinyHide = CompanionMicrogameWindowPolicy.hidePlacement(
            visibleFrame: visible,
            windowFrameSize: tinyPet,
            previousEdge: nil,
            entropy: 0
        )
        try require(
            CGRect(origin: tinyHide.origin, size: tinyPet).intersection(visible).size
                == tinyPet,
            "a pet smaller than the peek extent was unnecessarily clipped"
        )

        let invalidHide = CompanionMicrogameWindowPolicy.hidePlacement(
            visibleFrame: .null,
            windowFrameSize: CGSize(
                width: CGFloat.nan,
                height: CGFloat.infinity
            ),
            previousEdge: .bottom,
            entropy: UInt64.max
        )
        try require(
            invalidHide.origin.x.isFinite && invalidHide.origin.y.isFinite,
            "invalid hide geometry did not recover to finite coordinates"
        )

        print("Microgame window policy smoke: PASS (\(checks)/\(checks))")
    }
}
