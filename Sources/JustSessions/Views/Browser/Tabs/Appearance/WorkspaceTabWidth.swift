import CoreGraphics

@MainActor
enum WorkspaceTabWidth {
    static func fitting(
        shownTabCount: Int,
        shownSplitCount: Int,
        groupCount: Int,
        groupLabelsWidth: CGFloat,
        barWidth: CGFloat
    ) -> CGFloat {
        guard shownTabCount > 0 else { return WorkspaceTabMetrics.maximumWidth }
        let spaceBetweenGroups = WorkspaceTabMetrics.groupSpacing * CGFloat(max(groupCount - 1, 0))
        let widthForTabs = barWidth - 2 * WorkspaceTabMetrics.horizontalInset - spaceBetweenGroups - groupLabelsWidth
        var sharedWidth = (widthForTabs / CGFloat(shownTabCount)).rounded(.down)
        let plainTabCount = shownTabCount - shownSplitCount
        if shownSplitCount > 0, plainTabCount > 0, 2 * splitTabWidth(forTabWidth: sharedWidth) > sharedWidth {
            let widthForSplits = 2 * WorkspaceTabMetrics.minimumSplitTabWidth * CGFloat(shownSplitCount)
            sharedWidth = ((widthForTabs - widthForSplits) / CGFloat(plainTabCount)).rounded(.down)
        }
        return min(max(sharedWidth, WorkspaceTabMetrics.minimumWidth), WorkspaceTabMetrics.maximumWidth)
    }

    static func splitTabWidth(forTabWidth tabWidth: CGFloat) -> CGFloat {
        max((tabWidth / 2).rounded(.down), WorkspaceTabMetrics.minimumSplitTabWidth)
    }
}
