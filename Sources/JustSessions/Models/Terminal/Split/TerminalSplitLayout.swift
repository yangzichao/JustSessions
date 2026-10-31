import CoreGraphics

/// Where a shown split's panes and the resize area between them sit, as in Chrome's split view: the panes are inset
/// from the split area's edges, with the resize area between them. Side by side, the panes share the area's width; when
/// stacked, its height, the first pane on top. The fraction is the first pane's share of the length the two panes
/// share; it is kept where both panes stay large enough for a terminal, and the split starts even, as in Chrome. A drag
/// that brings the panes close to even snaps them even, as Chrome's snap point does.
enum TerminalSplitLayout {
    /// Between the split area's edges and its panes, as Chrome's `kSplitViewContentInset`. Chrome has no inset at the
    /// top, where its toolbar sits; with no toolbar here, the same band runs along the top too.
    static let contentInset: CGFloat = 8
    /// The resize area between the panes, which takes the drag: Chrome's 4-point handle and its 6 points of padding.
    /// It has a place of its own in the layout, so no terminal lies under it to take the click first.
    static let resizeAreaWidth: CGFloat = 10
    /// Neither pane gets narrower than this while the window has room for both, as Chrome's `kMinWebContentsSize`.
    static let minimumPaneWidth: CGFloat = 200
    /// Neither stacked pane gets shorter than this while the window has room for both: a CLI's input and status rows
    /// above the pane's mini toolbar.
    static let minimumPaneHeight: CGFloat = 120
    static let evenFraction: CGFloat = 0.5
    /// A drag leaving the first pane less than this from half the panes' length snaps it to half, as Chrome's
    /// `kSnapDistance` around its one snap point.
    static let snapDistance: CGFloat = 15

    struct PaneLengths: Equatable {
        var leading: CGFloat
        var trailing: CGFloat
    }

    /// The first pane, the resize area, and the second pane, in the split area's coordinates: left and right side by
    /// side, top and bottom when stacked.
    struct Frames: Equatable {
        var left: CGRect
        var resizeArea: CGRect
        var right: CGRect
    }

    static func minimumPaneLength(_ orientation: TerminalSplit.Orientation) -> CGFloat {
        orientation == .sideBySide ? minimumPaneWidth : minimumPaneHeight
    }

    /// The split area's width side by side, or its height stacked: the length its panes share.
    static func totalLength(of size: CGSize, _ orientation: TerminalSplit.Orientation) -> CGFloat {
        orientation == .sideBySide ? size.width : size.height
    }

    /// The length the two panes share, inside the insets and beside the resize area.
    static func availableLength(totalLength: CGFloat) -> CGFloat {
        max(totalLength - 2 * contentInset - resizeAreaWidth, 0)
    }

    /// `fraction` kept where each pane stays at least its minimum; an area too small for two such panes splits evenly.
    static func clampedFraction(
        _ fraction: CGFloat,
        totalLength: CGFloat,
        orientation: TerminalSplit.Orientation = .sideBySide
    ) -> CGFloat {
        let availableLength = availableLength(totalLength: totalLength)
        let minimumLength = minimumPaneLength(orientation)
        guard availableLength >= minimumLength * 2 else { return evenFraction }
        let minimumFraction = minimumLength / availableLength
        return min(max(fraction, minimumFraction), 1 - minimumFraction)
    }

    static func paneLengths(
        fraction: CGFloat,
        totalLength: CGFloat,
        orientation: TerminalSplit.Orientation = .sideBySide
    ) -> PaneLengths {
        let availableLength = availableLength(totalLength: totalLength)
        let leading = (availableLength * clampedFraction(fraction, totalLength: totalLength, orientation: orientation)).rounded()
        return PaneLengths(leading: leading, trailing: availableLength - leading)
    }

    /// Every part's place in a split area of `size`: side by side, the panes run the area's height inside the insets,
    /// and the resize area runs between them as tall as they are; stacked, the same turned on its side.
    static func frames(fraction: CGFloat, size: CGSize, orientation: TerminalSplit.Orientation = .sideBySide) -> Frames {
        let lengths = paneLengths(fraction: fraction, totalLength: totalLength(of: size, orientation), orientation: orientation)
        switch orientation {
        case .sideBySide:
            let height = max(size.height - 2 * contentInset, 0)
            let left = CGRect(x: contentInset, y: contentInset, width: lengths.leading, height: height)
            let resizeArea = CGRect(x: left.maxX, y: contentInset, width: resizeAreaWidth, height: height)
            let right = CGRect(x: resizeArea.maxX, y: contentInset, width: lengths.trailing, height: height)
            return Frames(left: left, resizeArea: resizeArea, right: right)
        case .stacked:
            let width = max(size.width - 2 * contentInset, 0)
            let top = CGRect(x: contentInset, y: contentInset, width: width, height: lengths.leading)
            let resizeArea = CGRect(x: contentInset, y: top.maxY, width: width, height: resizeAreaWidth)
            let bottom = CGRect(x: contentInset, y: resizeArea.maxY, width: width, height: lengths.trailing)
            return Frames(left: top, resizeArea: resizeArea, right: bottom)
        }
    }

    /// The fraction after the resize area is dragged `delta` points from where it sat at `startFraction`, even when
    /// that leaves the first pane within `snapDistance` of half the length, as Chrome's `CalculateRatioWithSnapPoints`.
    static func fraction(
        startingAt startFraction: CGFloat,
        draggedBy delta: CGFloat,
        totalLength: CGFloat,
        orientation: TerminalSplit.Orientation = .sideBySide
    ) -> CGFloat {
        let availableLength = availableLength(totalLength: totalLength)
        guard availableLength > 0 else { return evenFraction }
        let leadingLength = startFraction * availableLength + delta
        guard abs(leadingLength - evenFraction * availableLength) >= snapDistance else { return evenFraction }
        return clampedFraction(leadingLength / availableLength, totalLength: totalLength, orientation: orientation)
    }
}
