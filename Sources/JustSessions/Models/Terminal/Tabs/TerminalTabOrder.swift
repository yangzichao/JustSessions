import Foundation

enum TerminalTabOrder {
    static func insertionIndex(forProjectKey projectKey: String, amongTabProjectKeys tabProjectKeys: [String]) -> Int {
        guard let lastTabOfProject = tabProjectKeys.lastIndex(of: projectKey) else { return tabProjectKeys.count }
        return lastTabOfProject + 1
    }

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
