import CoreGraphics
import Testing
@testable import JustSessions

/// As in Chrome, tabs keep their full width while they fit, narrow together to share the bar as more open, and stop
/// at the narrowest width, past which the bar scrolls.
struct WorkspaceTabWidthTests {
    @Test func tabsThatFitTakeTheirFullWidth() {
        let width = WorkspaceTabWidth.fitting(shownTabCount: 3, shownSplitCount: 0, groupCount: 1, groupLabelsWidth: 100, barWidth: 1200)

        #expect(width == WorkspaceTabMetrics.maximumWidth)
    }

    @Test func moreTabsShareTheBarEvenly() {
        // 1032 minus the insets on both sides and one label leaves 900 for 10 tabs.
        let width = WorkspaceTabWidth.fitting(shownTabCount: 10, shownSplitCount: 0, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(width == 90)
    }

    @Test func groupLabelsAndTheSpaceBetweenGroupsLeaveTabsLessRoom() {
        // Two labels of 50 and one gap between the groups leave 900 - 14 for 10 tabs.
        let width = WorkspaceTabWidth.fitting(shownTabCount: 10, shownSplitCount: 0, groupCount: 2, groupLabelsWidth: 100, barWidth: 1032)

        #expect(width == 88)
    }

    @Test func tabsStopNarrowingAtTheNarrowestWidth() {
        let width = WorkspaceTabWidth.fitting(shownTabCount: 40, shownSplitCount: 0, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(width == WorkspaceTabMetrics.minimumWidth)
    }

    @Test func tabsTakeTheirFullWidthBeforeTheBarIsMeasured() {
        let width = WorkspaceTabWidth.fitting(shownTabCount: 40, shownSplitCount: 0, groupCount: 1, groupLabelsWidth: 0, barWidth: .infinity)

        #expect(width == WorkspaceTabMetrics.maximumWidth)
    }

    @Test func aSplitTakesOneTabsPlaceWithEachOfItsTabsHalfAsWide() {
        // Seven tabs, two of them a split, share 900 as six places.
        let tabWidth = WorkspaceTabWidth.fitting(shownTabCount: 6, shownSplitCount: 1, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(tabWidth == 150)
        #expect(WorkspaceTabWidth.splitTabWidth(forTabWidth: tabWidth) == 75)
        #expect(WorkspaceTabWidth.splitTabWidth(forTabWidth: WorkspaceTabMetrics.maximumWidth) == 100)
    }

    @Test func splitsAtTheirNarrowestKeepTheirWidthAndTheOtherTabsShareTheRest() {
        // Ten places, two of them splits, would share 900 at 90 each, but a split's two tabs take 2 × 56 = 112. The splits
        // take their 224, leaving 676 for eight tabs.
        let tabWidth = WorkspaceTabWidth.fitting(shownTabCount: 10, shownSplitCount: 2, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(tabWidth == 84)
        #expect(WorkspaceTabWidth.splitTabWidth(forTabWidth: tabWidth) == WorkspaceTabMetrics.minimumSplitTabWidth)
        #expect(8 * tabWidth + 2 * 2 * WorkspaceTabMetrics.minimumSplitTabWidth <= 900)
    }

    @Test func severalSplitsAtTheirNarrowestAllKeepTheirWidth() {
        // Nine places at 100 each, three of them splits taking 112 each, leave 564 for six tabs.
        let tabWidth = WorkspaceTabWidth.fitting(shownTabCount: 9, shownSplitCount: 3, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(tabWidth == 94)
    }

    @Test func tabsBesideSplitsStillStopNarrowingAtTheNarrowestWidth() {
        // Twelve places at 75 each, three of them splits, leave 564 for nine tabs: less than the narrowest width.
        let tabWidth = WorkspaceTabWidth.fitting(shownTabCount: 12, shownSplitCount: 3, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(tabWidth == WorkspaceTabMetrics.minimumWidth)
    }

    @Test func withoutSplitsTabsShareTheBarAsBefore() {
        let tabWidth = WorkspaceTabWidth.fitting(shownTabCount: 10, shownSplitCount: 0, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(tabWidth == 90)
    }

    @Test func aSplitTabsHalfWidthRoundsDownToWholePoints() {
        #expect(WorkspaceTabWidth.splitTabWidth(forTabWidth: 151) == 75)
    }

    @Test func aSplitTabStopsNarrowingAtItsNarrowestWidth() {
        #expect(WorkspaceTabWidth.splitTabWidth(forTabWidth: WorkspaceTabMetrics.minimumWidth) == WorkspaceTabMetrics.minimumSplitTabWidth)
    }
}
