import Foundation
import Testing

@testable import JustSessions

struct RecentlyClosedTabsTests {
    private let projectKey = ProjectLocation(host: .thisMac, path: "/tmp/project").key

    private func sessionTab(_ conversationID: String) -> ReopenableTerminalTab {
        ReopenableTerminalTab(conversationID: conversationID, projectDirectoryKey: projectKey, wasSelected: false)
    }

    private var plainTerminalTab: ReopenableTerminalTab {
        ReopenableTerminalTab(conversationID: nil, projectDirectoryKey: projectKey, wasSelected: false)
    }

    @Test func givesBackTheLatestClosedTabFirst() {
        var closedTabs = RecentlyClosedTabs()
        closedTabs.remember(sessionTab("first"), closedAt: 0)
        closedTabs.remember(plainTerminalTab, closedAt: 2)

        #expect(closedTabs.takeLatest() == RecentlyClosedTabs.ClosedTab(tab: plainTerminalTab, tabBarIndex: 2))
        #expect(closedTabs.takeLatest() == RecentlyClosedTabs.ClosedTab(tab: sessionTab("first"), tabBarIndex: 0))
        #expect(closedTabs.takeLatest() == nil)
        #expect(closedTabs.isEmpty)
    }

    @Test func aSessionClosedAgainKeepsOnlyItsLatestPlace() {
        var closedTabs = RecentlyClosedTabs()
        closedTabs.remember(sessionTab("session"), closedAt: 3)
        closedTabs.remember(plainTerminalTab, closedAt: 0)
        closedTabs.remember(plainTerminalTab, closedAt: 1)
        closedTabs.remember(sessionTab("session"), closedAt: 1)

        #expect(closedTabs.closedTabs.map(\.tab.conversationID) == [nil, nil, "session"])
        #expect(closedTabs.closedTabs.last?.tabBarIndex == 1)
    }

    @Test func keepsOnlyTheLatest25() {
        var closedTabs = RecentlyClosedTabs()
        for index in 0..<30 { closedTabs.remember(sessionTab("session \(index)"), closedAt: index) }

        #expect(closedTabs.closedTabs.count == RecentlyClosedTabs.maximumCount)
        #expect(closedTabs.closedTabs.first?.tab.conversationID == "session 5")
        #expect(closedTabs.closedTabs.last?.tab.conversationID == "session 29")
    }
}
