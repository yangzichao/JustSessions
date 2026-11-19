import CoreGraphics
import Testing

@testable import JustSessions

@MainActor
struct WorkspaceTabWidthTests {
    @Test func tabsThatFitTakeTheirFullWidth() {
        let width = WorkspaceTabWidth.fitting(shownTabCount: 3, shownSplitCount: 0, groupCount: 1, groupLabelsWidth: 100, barWidth: 1200)

        #expect(width == WorkspaceTabMetrics.maximumWidth)
    }

    @Test func moreTabsShareTheBarEvenly() {
        let width = WorkspaceTabWidth.fitting(shownTabCount: 10, shownSplitCount: 0, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(width == 90)
    }

    @Test func groupLabelsAndTheSpaceBetweenGroupsLeaveTabsLessRoom() {
        let width = WorkspaceTabWidth.fitting(shownTabCount: 10, shownSplitCount: 0, groupCount: 2, groupLabelsWidth: 100, barWidth: 1032)

        #expect(width == 88)
    }

    @Test func tabsStopNarrowingAtTheNarrowestWidth() {
        let width = WorkspaceTabWidth.fitting(shownTabCount: 40, shownSplitCount: 0, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(width == WorkspaceTabMetrics.minimumWidth)
    }

    @Test func tabsTakeTheirFullWidthBeforeTheBarIsMeasured() {
        let width = WorkspaceTabWidth.fitting(
            shownTabCount: 40, shownSplitCount: 0, groupCount: 1, groupLabelsWidth: 0, barWidth: .infinity)

        #expect(width == WorkspaceTabMetrics.maximumWidth)
    }

    @Test func aSplitTakesOneTabsPlaceWithEachOfItsTabsHalfAsWide() {
        let tabWidth = WorkspaceTabWidth.fitting(shownTabCount: 6, shownSplitCount: 1, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(tabWidth == 150)
        #expect(WorkspaceTabWidth.splitTabWidth(forTabWidth: tabWidth) == 75)
        #expect(WorkspaceTabWidth.splitTabWidth(forTabWidth: WorkspaceTabMetrics.maximumWidth) == 100)
    }

    @Test func splitsAtTheirNarrowestKeepTheirWidthAndTheOtherTabsShareTheRest() {
        let tabWidth = WorkspaceTabWidth.fitting(
            shownTabCount: 10, shownSplitCount: 2, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(tabWidth == 84)
        #expect(WorkspaceTabWidth.splitTabWidth(forTabWidth: tabWidth) == WorkspaceTabMetrics.minimumSplitTabWidth)
        #expect(8 * tabWidth + 2 * 2 * WorkspaceTabMetrics.minimumSplitTabWidth <= 900)
    }

    @Test func severalSplitsAtTheirNarrowestAllKeepTheirWidth() {
        let tabWidth = WorkspaceTabWidth.fitting(shownTabCount: 9, shownSplitCount: 3, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(tabWidth == 94)
    }

    @Test func tabsBesideSplitsStillStopNarrowingAtTheNarrowestWidth() {
        let tabWidth = WorkspaceTabWidth.fitting(
            shownTabCount: 12, shownSplitCount: 3, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(tabWidth == WorkspaceTabMetrics.minimumWidth)
    }

    @Test func withoutSplitsTabsShareTheBarAsBefore() {
        let tabWidth = WorkspaceTabWidth.fitting(
            shownTabCount: 10, shownSplitCount: 0, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(tabWidth == 90)
    }

    @Test func aSplitTabsHalfWidthRoundsDownToWholePoints() {
        #expect(WorkspaceTabWidth.splitTabWidth(forTabWidth: 151) == 75)
    }

    @Test func aSplitTabStopsNarrowingAtItsNarrowestWidth() {
        #expect(WorkspaceTabWidth.splitTabWidth(forTabWidth: WorkspaceTabMetrics.minimumWidth) == WorkspaceTabMetrics.minimumSplitTabWidth)
    }
}
