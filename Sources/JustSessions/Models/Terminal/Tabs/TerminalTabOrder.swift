import Foundation

/// Where tabs open and which tab shows after one closes or its group collapses, so each project's tabs stay side by
/// side, like a tab group in a browser. Tabs are given by their group keys, in tab bar order: a tab's project key, or
/// while it is in a split, its split's group key; see `TerminalSplit.groupKey`.
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

    /// The tab to show once the selected tab's group collapses: the nearest tab still in sight, the right one first.
    /// Nil when every other tab is in a collapsed group too, so the selected tab keeps showing.
    static func indexToSelect(
        afterCollapsingGroupOfTabAt selectedIndex: Int,
        collapsedProjectKeys: Set<String>,
        amongTabProjectKeys tabProjectKeys: [String]
    ) -> Int? {
        let hiddenProjectKeys = collapsedProjectKeys.union([tabProjectKeys[selectedIndex]])
        let tabsToTheRight = tabProjectKeys.indices.suffix(from: selectedIndex + 1)
        let tabsToTheLeft = tabProjectKeys.indices.prefix(upTo: selectedIndex).reversed()
        return (Array(tabsToTheRight) + tabsToTheLeft).first { !hiddenProjectKeys.contains(tabProjectKeys[$0]) }
    }
}
