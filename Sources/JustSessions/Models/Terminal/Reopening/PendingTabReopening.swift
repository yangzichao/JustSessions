import Foundation

/// Tabs from the last quit that wait for their host to list its sessions, since a session tab reopens from the listed
/// session. Hosts list at different times, so each tab goes in by its place in the saved order, between the tabs
/// reopened before it.
struct PendingTabReopening {
    struct WaitingTab {
        /// The tab's place in the saved order.
        let savedPosition: Int
        let tab: ReopenableTerminalTab
    }

    private(set) var waitingTabs: [WaitingTab]
    /// The saved place of each reopened tab, by tab id.
    private var savedPositionsOfReopenedTabs: [UUID: Int] = [:]

    init(tabs: [ReopenableTerminalTab] = []) {
        waitingTabs = tabs.enumerated().map { WaitingTab(savedPosition: $0.offset, tab: $0.element) }
    }

    /// Removes and returns the waiting tabs that `shouldTake` picks, in saved order.
    mutating func takeWaitingTabs(where shouldTake: (ReopenableTerminalTab) -> Bool) -> [WaitingTab] {
        let taken = waitingTabs.filter { shouldTake($0.tab) }
        waitingTabs.removeAll { shouldTake($0.tab) }
        return taken
    }

    mutating func recordReopenedTab(id: UUID, savedPosition: Int) {
        savedPositionsOfReopenedTabs[id] = savedPosition
    }

    mutating func returnWaitingTab(_ waitingTab: WaitingTab) {
        waitingTabs.append(waitingTab)
        waitingTabs.sort { $0.savedPosition < $1.savedPosition }
    }

    /// Where a tab with this saved place goes among the open tabs: before the first reopened tab saved after it, or
    /// else after the last reopened tab saved before it. With no reopened tab open, it goes first, ahead of tabs
    /// opened since launch.
    func insertionIndex(forSavedPosition savedPosition: Int, amongOpenTabIDs openTabIDs: [UUID]) -> Int {
        if let laterTabIndex = openTabIDs.firstIndex(where: { savedPositionsOfReopenedTabs[$0].map { $0 > savedPosition } ?? false }) {
            return laterTabIndex
        }
        if let earlierTabIndex = openTabIDs.lastIndex(where: { savedPositionsOfReopenedTabs[$0] != nil }) {
            return earlierTabIndex + 1
        }
        return 0
    }
}
