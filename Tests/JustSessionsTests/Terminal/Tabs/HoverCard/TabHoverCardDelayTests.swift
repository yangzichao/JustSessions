import CoreGraphics
import Testing
@testable import JustSessions

/// As in Chrome, the first hover card waits less the narrower the tabs are, since their titles are cut more.
struct TabHoverCardDelayTests {
    @Test func narrowestTabsWaitTheLeast() {
        #expect(TabHoverCardDelay.beforeShowing(tabWidth: WorkspaceTabMetrics.minimumWidth) == .milliseconds(300))
    }

    @Test func splitTabsNarrowerThanAnyOtherTabWaitTheLeastToo() {
        #expect(TabHoverCardDelay.beforeShowing(tabWidth: WorkspaceTabMetrics.minimumSplitTabWidth) == .milliseconds(300))
    }

    @Test func fullWidthTabsWaitTheLongestWithChromesExtraDelay() {
        #expect(TabHoverCardDelay.beforeShowing(tabWidth: WorkspaceTabMetrics.maximumWidth) == .milliseconds(1300))
    }

    @Test func narrowedTabsWaitBetweenOnALogScale() {
        // Halfway between the narrowest and the widest is already most of the way up a log scale.
        let delay = TabHoverCardDelay.beforeShowing(tabWidth: 136)

        #expect(delay > .milliseconds(700))
        #expect(delay < .milliseconds(800))
    }

    @Test func widerTabsNeverWaitLess() {
        let delays = stride(from: WorkspaceTabMetrics.minimumWidth, through: WorkspaceTabMetrics.maximumWidth, by: 4)
            .map { TabHoverCardDelay.beforeShowing(tabWidth: $0) }

        #expect(delays == delays.sorted())
    }
}
