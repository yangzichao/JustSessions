import CoreGraphics

/// Where a shown split's panes and the resize area between them sit, as in Chrome's split view: the panes are inset
/// from the split area's edges, with the resize area between them. The fraction is the left pane's share of the width
/// the two panes share; it is kept where both panes stay wide enough for a terminal, and the split starts even, as in
/// Chrome.
enum TerminalSplitLayout {
    /// Between the split area's edges and its panes, as Chrome's `kSplitViewContentInset`. Chrome has no inset at the
    /// top, where its toolbar sits; with no toolbar here, the same band runs along the top too.
    static let contentInset: CGFloat = 8
    /// The resize area between the panes, which takes the drag: Chrome's 4-point handle and its 6 points of padding.
    /// It has a place of its own in the layout, so no terminal lies under it to take the click first.
    static let resizeAreaWidth: CGFloat = 10
    /// Neither pane gets narrower than this while the window has room for both, as Chrome's `kMinWebContentsSize`.
    static let minimumPaneWidth: CGFloat = 200
    static let evenFraction: CGFloat = 0.5

    struct PaneWidths: Equatable {
        var leading: CGFloat
        var trailing: CGFloat
    }

    /// The left pane, the resize area, and the right pane, in the split area's coordinates.
    struct Frames: Equatable {
        var left: CGRect
        var resizeArea: CGRect
        var right: CGRect
    }

    /// The width the two panes share, inside the insets and beside the resize area.
    static func availableWidth(totalWidth: CGFloat) -> CGFloat {
        max(totalWidth - 2 * contentInset - resizeAreaWidth, 0)
    }

    /// `fraction` kept where each pane stays at least `minimumPaneWidth`; a window too narrow for two such
    /// panes splits evenly.
    static func clampedFraction(_ fraction: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let availableWidth = availableWidth(totalWidth: totalWidth)
        guard availableWidth >= minimumPaneWidth * 2 else { return evenFraction }
        let minimumFraction = minimumPaneWidth / availableWidth
        return min(max(fraction, minimumFraction), 1 - minimumFraction)
    }

    static func paneWidths(fraction: CGFloat, totalWidth: CGFloat) -> PaneWidths {
        let availableWidth = availableWidth(totalWidth: totalWidth)
        let leading = (availableWidth * clampedFraction(fraction, totalWidth: totalWidth)).rounded()
        return PaneWidths(leading: leading, trailing: availableWidth - leading)
    }

    /// Every part's place in a split area of `size`: the panes run the area's height inside the insets, and the resize
    /// area runs between them as tall as they are.
    static func frames(fraction: CGFloat, size: CGSize) -> Frames {
        let widths = paneWidths(fraction: fraction, totalWidth: size.width)
        let height = max(size.height - 2 * contentInset, 0)
        let left = CGRect(x: contentInset, y: contentInset, width: widths.leading, height: height)
        let resizeArea = CGRect(x: left.maxX, y: contentInset, width: resizeAreaWidth, height: height)
        let right = CGRect(x: resizeArea.maxX, y: contentInset, width: widths.trailing, height: height)
        return Frames(left: left, resizeArea: resizeArea, right: right)
    }

    /// The fraction after the resize area is dragged `delta` points from where it sat at `startFraction`.
    static func fraction(startingAt startFraction: CGFloat, draggedBy delta: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let availableWidth = availableWidth(totalWidth: totalWidth)
        guard availableWidth > 0 else { return evenFraction }
        return clampedFraction(startFraction + delta / availableWidth, totalWidth: totalWidth)
    }
}
