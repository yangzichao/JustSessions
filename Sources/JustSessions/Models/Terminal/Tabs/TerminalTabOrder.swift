import Foundation

/// Where tabs open and which tab shows after one closes, so each project's tabs stay side by side, like a tab group
/// in a browser. Tabs are given by their project keys, in tab bar order.
enum TerminalTabOrder {
    /// Right after the project's last tab, or at the end when the project has none open.
    static func insertionIndex(forProjectKey projectKey: String, amongTabProjectKeys tabProjectKeys: [String]) -> Int {
        guard let lastTabOfProject = tabProjectKeys.lastIndex(of: projectKey) else { return tabProjectKeys.count }
        return lastTabOfProject + 1
    }

    /// The tab to show, as an index once the closed tab is gone: a neighbor in the same project, the right one first;
    /// with none left there, the tab that took the closed one's place, or else the one before it. Nil when no tab is left.
    static func indexToSelect(afterClosingTabAt closedIndex: Int, amongTabProjectKeys tabProjectKeys: [String]) -> Int? {
        var remainingProjectKeys = tabProjectKeys
        let closedProjectKey = remainingProjectKeys.remove(at: closedIndex)
        let rightNeighbor = closedIndex < remainingProjectKeys.count ? closedIndex : nil
        let leftNeighbor = closedIndex > 0 ? closedIndex - 1 : nil
        let sameProjectNeighbor = [rightNeighbor, leftNeighbor]
            .compactMap { $0 }
            .first { remainingProjectKeys[$0] == closedProjectKey }
        return sameProjectNeighbor ?? rightNeighbor ?? leftNeighbor
    }
}
