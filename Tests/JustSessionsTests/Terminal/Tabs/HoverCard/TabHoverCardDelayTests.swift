import CoreGraphics
import Testing

@testable import JustSessions

@MainActor
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
