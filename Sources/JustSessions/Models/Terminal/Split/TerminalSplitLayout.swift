import CoreGraphics

/// Where the draggable divider parts a split's two panes. The fraction is the leading pane's share of the
/// width beside the divider; it is kept where both panes stay wide enough for a terminal, and the split starts
/// even, as in Chrome.
enum TerminalSplitLayout {
    /// The gutter between the panes, which takes the drag. It has a place of its own in the layout, so no terminal
    /// lies under it to take the click first.
    static let dividerWidth: CGFloat = 8
    /// Neither pane gets narrower than this while the window has room for both.
    static let minimumPaneWidth: CGFloat = 200
    static let evenFraction: CGFloat = 0.5

    struct PaneWidths: Equatable {
        var leading: CGFloat
        var trailing: CGFloat
    }

    /// The width the two panes share, beside the divider.
    static func availableWidth(totalWidth: CGFloat) -> CGFloat {
        max(totalWidth - dividerWidth, 0)
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

    /// The fraction after the divider is dragged `delta` points from where it sat at `startFraction`.
    static func fraction(startingAt startFraction: CGFloat, draggedBy delta: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let availableWidth = availableWidth(totalWidth: totalWidth)
        guard availableWidth > 0 else { return evenFraction }
        return clampedFraction(startFraction + delta / availableWidth, totalWidth: totalWidth)
    }

    /// Where the divider sits once the split's pair changes from `oldPair` to `newPair`. Swapped panes keep their
    /// widths as they trade sides; a tab that keeps its side, replaced in place by reconnecting or the selected
    /// tab with a new partner, keeps the divider where it was; any other pair starts even, as in Chrome.
    static func fraction(
        _ current: CGFloat,
        afterPairChangeFrom oldPair: TerminalSplitPair?,
        to newPair: TerminalSplitPair
    ) -> CGFloat {
        guard let oldPair else { return evenFraction }
        if newPair == oldPair.swapped { return 1 - current }
        if newPair.leadingID == oldPair.leadingID || newPair.trailingID == oldPair.trailingID { return current }
        return evenFraction
    }
}
