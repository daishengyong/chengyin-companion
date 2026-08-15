import CoreGraphics

/// Deterministic geometry shared by AppKit window sizing and the SwiftUI play
/// palette. The plan keeps every category reachable without introducing a
/// scroll-only menu when the active display has a constrained visible frame.
public struct CompanionPlayPaletteLayoutPlan: Equatable, Sendable {
    public let contentSize: CGSize
    public let maximumPaletteWidth: CGFloat
    public let columnCount: Int
    public let minimumButtonWidth: CGFloat
    public let isCompact: Bool
    public let showsReturnHint: Bool
    public let usesCompactFooter: Bool

    public init(
        contentSize: CGSize,
        maximumPaletteWidth: CGFloat,
        columnCount: Int,
        minimumButtonWidth: CGFloat,
        isCompact: Bool,
        showsReturnHint: Bool,
        usesCompactFooter: Bool
    ) {
        self.contentSize = contentSize
        self.maximumPaletteWidth = maximumPaletteWidth
        self.columnCount = columnCount
        self.minimumButtonWidth = minimumButtonWidth
        self.isCompact = isCompact
        self.showsReturnHint = showsReturnHint
        self.usesCompactFooter = usesCompactFooter
    }
}

public enum CompanionPlayPaletteLayout {
    public static let maximumCategoryItemCount = 9

    public static func plan(
        visibleFrame: CGRect
    ) -> CompanionPlayPaletteLayoutPlan {
        let visible = normalizedVisibleFrame(visibleFrame)
        let contentSize = CGSize(
            width: min(600, visible.width),
            // The largest category has nine buttons. A 420-point canvas keeps
            // all three rows, the category switcher and footer visible while
            // opening farther upward from a bottom-docked pet. Taller windows
            // made the panel feel scroll-bound even though it had no scroll
            // view, especially on displays with a large Dock or menu bar.
            height: min(420, visible.height)
        )
        let isCompact = contentSize.width < 600 || contentSize.height < 420
        let paletteWidth = max(160, min(560, contentSize.width - 20))
        let usableGridWidth = max(0, paletteWidth - (isCompact ? 20 : 32))

        let columns: Int
        let minimumButtonWidth: CGFloat
        if usableGridWidth >= 244 {
            columns = 3
            minimumButtonWidth = isCompact ? 76 : 136
        } else if usableGridWidth >= 172 {
            columns = 2
            minimumButtonWidth = 82
        } else {
            columns = 1
            minimumButtonWidth = min(136, usableGridWidth)
        }

        return CompanionPlayPaletteLayoutPlan(
            contentSize: contentSize,
            maximumPaletteWidth: paletteWidth,
            columnCount: columns,
            minimumButtonWidth: max(44, minimumButtonWidth),
            isCompact: isCompact,
            showsReturnHint: !isCompact,
            usesCompactFooter: isCompact
        )
    }

    private static func normalizedVisibleFrame(_ candidate: CGRect) -> CGRect {
        guard candidate.origin.x.isFinite,
              candidate.origin.y.isFinite,
              candidate.width.isFinite,
              candidate.height.isFinite,
              candidate.width > 0,
              candidate.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1_440, height: 900)
        }
        return candidate
    }
}
