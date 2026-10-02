import Foundation
import Testing
@testable import JustSessions

/// Hosts list their sessions at different times; each reopened tab still lands in its saved place.
struct PendingTabReopeningTests {
    private func tabs(_ count: Int) -> [ReopenableTerminalTab] {
        (0..<count).map { ReopenableTerminalTab(conversationID: "claude:\($0)", projectDirectoryKey: "/p", wasSelected: false) }
    }

    @Test func takesTheChosenTabsInSavedOrderAndKeepsTheRestWaiting() {
        var pending = PendingTabReopening(tabs: tabs(4))

        let taken = pending.takeWaitingTabs { $0.conversationID == "claude:1" || $0.conversationID == "claude:3" }

        #expect(taken.map(\.savedPosition) == [1, 3])
        #expect(pending.waitingTabs.map(\.savedPosition) == [0, 2])
    }

    @Test func theFirstReopenedTabGoesAheadOfTabsOpenedSinceLaunch() {
        let pending = PendingTabReopening(tabs: tabs(2))

        #expect(pending.insertionIndex(forSavedPosition: 1, amongOpenTabIDs: [UUID(), UUID()]) == 0)
    }

    @Test func aTabGoesBeforeTheFirstReopenedTabSavedAfterIt() {
        var pending = PendingTabReopening(tabs: tabs(4))
        let second = UUID(), fourth = UUID()
        pending.recordReopenedTab(id: second, savedPosition: 1)
        pending.recordReopenedTab(id: fourth, savedPosition: 3)

        #expect(pending.insertionIndex(forSavedPosition: 0, amongOpenTabIDs: [second, fourth]) == 0)
        #expect(pending.insertionIndex(forSavedPosition: 2, amongOpenTabIDs: [second, fourth]) == 1)
    }

    @Test func aTabSavedAfterEveryReopenedTabGoesRightAfterTheLastOfThem() {
        var pending = PendingTabReopening(tabs: tabs(3))
        let first = UUID(), openedSinceLaunch = UUID()
        pending.recordReopenedTab(id: first, savedPosition: 0)

        #expect(pending.insertionIndex(forSavedPosition: 2, amongOpenTabIDs: [first, openedSinceLaunch]) == 1)
    }
}
