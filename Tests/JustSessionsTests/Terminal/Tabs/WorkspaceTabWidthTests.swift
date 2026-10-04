import CoreGraphics
import Testing
@testable import JustSessions

/// As in Chrome, tabs keep their full width while they fit, narrow together to share the bar as more open, and stop
/// at the narrowest width, past which the bar scrolls.
struct WorkspaceTabWidthTests {
    @Test func tabsThatFitTakeTheirFullWidth() {
        let width = WorkspaceTabWidth.fitting(shownTabCount: 3, groupCount: 1, groupLabelsWidth: 100, barWidth: 1200)

        #expect(width == WorkspaceTabMetrics.maximumWidth)
    }

    @Test func moreTabsShareTheBarEvenly() {
        // 1032 minus the insets on both sides and one label leaves 900 for 10 tabs.
        let width = WorkspaceTabWidth.fitting(shownTabCount: 10, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(width == 90)
    }

    @Test func groupLabelsAndTheSpaceBetweenGroupsLeaveTabsLessRoom() {
        // Two labels of 50 and one gap between the groups leave 900 - 14 for 10 tabs.
        let width = WorkspaceTabWidth.fitting(shownTabCount: 10, groupCount: 2, groupLabelsWidth: 100, barWidth: 1032)

        #expect(width == 88)
    }

    @Test func tabsStopNarrowingAtTheNarrowestWidth() {
        let width = WorkspaceTabWidth.fitting(shownTabCount: 40, groupCount: 1, groupLabelsWidth: 100, barWidth: 1032)

        #expect(width == WorkspaceTabMetrics.minimumWidth)
    }

    @Test func tabsTakeTheirFullWidthBeforeTheBarIsMeasured() {
        let width = WorkspaceTabWidth.fitting(shownTabCount: 40, groupCount: 1, groupLabelsWidth: 0, barWidth: .infinity)

        #expect(width == WorkspaceTabMetrics.maximumWidth)
    }
}
