import Foundation

struct RecentlyClosedTabs: Equatable {
    struct ClosedTab: Equatable {
        let tab: ReopenableTerminalTab
        let tabBarIndex: Int
    }

    static let maximumCount = 25

    private(set) var closedTabs: [ClosedTab] = []

    var isEmpty: Bool { closedTabs.isEmpty }

    mutating func remember(_ tab: ReopenableTerminalTab, closedAt tabBarIndex: Int) {
        if let conversationID = tab.conversationID {
            closedTabs.removeAll { $0.tab.conversationID == conversationID }
        }
        closedTabs.append(ClosedTab(tab: tab, tabBarIndex: tabBarIndex))
        if closedTabs.count > Self.maximumCount {
            closedTabs.removeFirst(closedTabs.count - Self.maximumCount)
        }
    }

    mutating func takeLatest() -> ClosedTab? {
        closedTabs.popLast()
    }
}
