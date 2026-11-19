import Foundation

struct PendingTabReopening {
    struct WaitingTab {
        let savedPosition: Int
        let tab: ReopenableTerminalTab
    }

    private(set) var waitingTabs: [WaitingTab]
    private var savedPositionsOfReopenedTabs: [UUID: Int] = [:]

    init(tabs: [ReopenableTerminalTab] = []) {
        waitingTabs = tabs.enumerated().map { WaitingTab(savedPosition: $0.offset, tab: $0.element) }
    }

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
