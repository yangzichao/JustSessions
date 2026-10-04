import CoreGraphics

/// How wide the tabs are, as in Chrome: every tab takes its full width while they all fit in the bar, then they
/// narrow together as more open, each title cut shorter, down to the narrowest width. Past that, the bar scrolls.
/// A split's two tabs together take one tab's place, each half as wide, as Chrome's split tabs are.
enum WorkspaceTabWidth {
    /// One width for every shown tab in no split.
    /// - Parameters:
    ///   - shownTabCount: tabs outside collapsed groups, a split's two tabs counting as one.
    ///   - groupCount: every group, collapsed or not; each one's label takes room in the bar.
    ///   - groupLabelsWidth: every group label's width, with the space after it.
    ///   - barWidth: the bar's visible width; infinite until measured, which gives tabs their full width.
    static func fitting(shownTabCount: Int, groupCount: Int, groupLabelsWidth: CGFloat, barWidth: CGFloat) -> CGFloat {
        guard shownTabCount > 0 else { return WorkspaceTabMetrics.maximumWidth }
        let spaceBetweenGroups = WorkspaceTabMetrics.groupSpacing * CGFloat(max(groupCount - 1, 0))
        let widthForTabs = barWidth - 2 * WorkspaceTabMetrics.horizontalInset - spaceBetweenGroups - groupLabelsWidth
        // Whole points keep every tab's title on the pixel grid.
        let sharedWidth = (widthForTabs / CGFloat(shownTabCount)).rounded(.down)
        return min(max(sharedWidth, WorkspaceTabMetrics.minimumWidth), WorkspaceTabMetrics.maximumWidth)
    }

    /// The width of each of a split's two tabs, beside tabs `tabWidth` wide: half of it in whole points, but never
    /// narrower than `minimumSplitTabWidth`.
    static func splitTabWidth(forTabWidth tabWidth: CGFloat) -> CGFloat {
        max((tabWidth / 2).rounded(.down), WorkspaceTabMetrics.minimumSplitTabWidth)
    }
}
