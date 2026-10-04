import Foundation

/// The tab bar's order and its splits, changed as Chrome's tab strip changes them, worked out on tab ids and project
/// keys alone so the store only applies the result. Every change keeps the order's rules: the tabs of one group sit
/// together, a split's two tabs sit side by side, and a split's group is the project of a tab in that group, its own
/// or another, so no group is named for a project none of its tabs belong to. A tab's group is its split's while it is
/// in one, or else its own project's.
struct TerminalTabStrip: Equatable {
    struct Tab: Equatable {
        let id: UUID
        let projectKey: String
    }

    private(set) var tabs: [Tab]
    private(set) var splits: [TerminalSplit]

    init(tabs: [Tab], splits: [TerminalSplit] = []) {
        self.tabs = tabs
        self.splits = splits
    }

    var tabIDs: [UUID] { tabs.map(\.id) }

    /// Every tab's group key, in tab bar order.
    var groupKeys: [String] { tabs.map(groupKey(of:)) }

    func split(containing tabID: UUID) -> TerminalSplit? {
        splits.first { $0.contains(tabID) }
    }

    func groupKey(of tab: Tab) -> String {
        split(containing: tab.id)?.groupKey ?? tab.projectKey
    }

    /// The split's left and right tabs: the one that comes first in the tab bar shows on the left. Nil unless both
    /// tabs are open.
    func sides(of split: TerminalSplit) -> TerminalSplit.Sides? {
        let splitTabIDs = tabs.map(\.id).filter(split.contains)
        guard splitTabIDs.count == 2 else { return nil }
        return TerminalSplit.Sides(left: splitTabIDs[0], right: splitTabIDs[1])
    }

    // MARK: - Opening tabs

    /// Where a new tab of the project opens: right after the last tab in the project's group, which may be a split's,
    /// or at the end with none open.
    func insertionIndex(forNewTabOfProject projectKey: String) -> Int {
        TerminalTabOrder.insertionIndex(forProjectKey: projectKey, amongTabProjectKeys: groupKeys)
    }

    /// Where a tab of the project reopened from the last quit goes: at `index`, its saved place, unless a tab there
    /// would part a split's two tabs or sit among another group's tabs; then where a new tab of its project opens.
    func insertionIndex(forReopenedTabOfProject projectKey: String, at index: Int) -> Int {
        let index = min(max(index, 0), tabs.count)
        guard index > 0, index < tabs.count else { return index }
        let groupKeys = groupKeys
        let partsASplit = split(containing: tabs[index - 1].id)?.contains(tabs[index].id) == true
        let isAmongAnotherGroup = groupKeys[index - 1] == groupKeys[index] && groupKeys[index] != projectKey
        return partsASplit || isAmongAnotherGroup ? insertionIndex(forNewTabOfProject: projectKey) : index
    }

    // MARK: - Splits

    /// Links the tab `joiningID` with `pivotID`, as Chrome's AddToNewSplit does. The joining tab moves next to the
    /// pivot on the side it came from: right before it, as the left pane, when it came from before it in the tab bar,
    /// or else right after it, as the right pane. The split takes the pivot's group, so a tab from another project
    /// joins the pivot's group. Changes nothing and returns nil unless both tabs are open, different, and in no split.
    @discardableResult
    mutating func addSplit(joining joiningID: UUID, beside pivotID: UUID, splitID: UUID = UUID()) -> TerminalSplit? {
        guard joiningID != pivotID,
              let joiningIndex = index(of: joiningID),
              let pivotIndex = index(of: pivotID),
              split(containing: joiningID) == nil,
              split(containing: pivotID) == nil else { return nil }
        let split = TerminalSplit(id: splitID, tabIDs: (pivotID, joiningID), groupKey: groupKey(of: tabs[pivotIndex]))
        let joiningTab = tabs.remove(at: joiningIndex)
        let pivotIndexAfterRemoval = joiningIndex < pivotIndex ? pivotIndex - 1 : pivotIndex
        tabs.insert(joiningTab, at: joiningIndex < pivotIndex ? pivotIndexAfterRemoval : pivotIndexAfterRemoval + 1)
        splits.append(split)
        // The joining tab may have been the last of its group's project, the one another split's group is named for.
        regroupSplitsOutsideTheirProjects()
        return split
    }

    /// The split's two tabs trade places in the tab bar, so its panes trade sides, as Chrome's ReverseTabsInSplit.
    mutating func reverseSplit(_ splitID: UUID) {
        guard let split = splits.first(where: { $0.id == splitID }),
              let sides = sides(of: split),
              let leftIndex = index(of: sides.left),
              let rightIndex = index(of: sides.right) else { return }
        tabs.swapAt(leftIndex, rightIndex)
    }

    /// Unlinks the split, as Chrome's RemoveSplit. Each tab is in its own project's group again: one from another
    /// project than the split's group goes back to its project's tabs, as a new tab of its project would open.
    mutating func separateSplit(_ splitID: UUID) {
        guard let split = splits.first(where: { $0.id == splitID }) else { return }
        splits.removeAll { $0.id == splitID }
        guard let sides = sides(of: split) else { return }
        // The right tab still counts in the split's group while the left one finds its place, so two tabs going back to
        // the same project keep their order there.
        returnToProjectGroup(sides.left, from: split.groupKey, countingInGroup: [sides.right: split.groupKey])
        returnToProjectGroup(sides.right, from: split.groupKey)
        regroupSplitsOutsideTheirProjects()
    }

    /// Separates every split, from the first in the tab bar to the last.
    mutating func separateAllSplits() {
        for tabID in tabIDs {
            if let split = split(containing: tabID) { separateSplit(split.id) }
        }
    }

    /// Swaps the tab `incomingID`, in no split, into the split in the place of its tab `outgoingID`, as Chrome's
    /// UpdateTabInSplit with kSwap: the two trade places in the tab bar, the incoming tab joining the split, which
    /// keeps its id and group, and the outgoing one leaving it. The outgoing tab then sits in the incoming tab's
    /// project group; when its own project is another, it goes back to its project's tabs. Returns whether the swap
    /// was made.
    @discardableResult
    mutating func swap(_ incomingID: UUID, intoSplit splitID: UUID, replacing outgoingID: UUID) -> Bool {
        guard incomingID != outgoingID,
              let splitIndex = splits.firstIndex(where: { $0.id == splitID }),
              splits[splitIndex].contains(outgoingID),
              split(containing: incomingID) == nil,
              let incomingIndex = index(of: incomingID),
              let outgoingIndex = index(of: outgoingID) else { return false }
        let incomingProjectKey = tabs[incomingIndex].projectKey
        tabs.swapAt(incomingIndex, outgoingIndex)
        splits[splitIndex] = splits[splitIndex].replacing(outgoingID, with: incomingID)
        returnToProjectGroup(outgoingID, from: incomingProjectKey)
        regroupSplitsOutsideTheirProjects()
        return true
    }

    /// Takes the tab out of the tab bar. A split it was in is unlinked, as Chrome closes one view of a split, and the
    /// other tab goes back to its project's tabs as when the split is separated.
    mutating func removeTab(_ tabID: UUID) {
        guard let index = index(of: tabID) else { return }
        tabs.remove(at: index)
        if let split = split(containing: tabID) {
            splits.removeAll { $0.id == split.id }
            if let partner = split.partner(of: tabID) { returnToProjectGroup(partner, from: split.groupKey) }
        }
        regroupSplitsOutsideTheirProjects()
    }

    // MARK: - Helpers

    private func index(of tabID: UUID) -> Int? {
        tabs.firstIndex { $0.id == tabID }
    }

    /// Whether a tab of the split's group project shows in that group: one of the split's own, or another.
    private func hasTabOfItsGroupsProject(_ split: TerminalSplit) -> Bool {
        tabs.contains { $0.projectKey == split.groupKey && groupKey(of: $0) == split.groupKey }
    }

    /// A split whose group no longer holds a tab of the group's project, as when that project's last tab there closed
    /// or left, would leave a group named for a project none of its tabs belong to. It takes its left tab's project
    /// instead, and its two tabs, in their order, move to where a new tab of that project would open. That project
    /// is one of its own tabs', so no split needs this twice, and its tabs leaving the group take no other split's
    /// project tab with them.
    private mutating func regroupSplitsOutsideTheirProjects() {
        while let splitIndex = splits.firstIndex(where: { sides(of: $0) != nil && !hasTabOfItsGroupsProject($0) }),
              let sides = sides(of: splits[splitIndex]),
              let leftIndex = index(of: sides.left) {
            let projectKey = tabs[leftIndex].projectKey
            splits[splitIndex] = splits[splitIndex].regrouped(into: projectKey)
            let splitTabs = tabs.filter { $0.id == sides.left || $0.id == sides.right }
            tabs.removeAll { $0.id == sides.left || $0.id == sides.right }
            tabs.insert(contentsOf: splitTabs, at: TerminalTabOrder.insertionIndex(forProjectKey: projectKey, amongTabProjectKeys: groupKeys))
        }
    }

    /// Moves a tab in no split that sits in the group `groupKey` to where a new tab of its project would open, unless
    /// that group is its project's. `countingInGroup` gives tabs that still count in a group other than their own.
    private mutating func returnToProjectGroup(_ tabID: UUID, from groupKey: String, countingInGroup: [UUID: String] = [:]) {
        guard let index = index(of: tabID), tabs[index].projectKey != groupKey else { return }
        let tab = tabs.remove(at: index)
        let otherGroupKeys = tabs.map { countingInGroup[$0.id] ?? self.groupKey(of: $0) }
        tabs.insert(tab, at: TerminalTabOrder.insertionIndex(forProjectKey: tab.projectKey, amongTabProjectKeys: otherGroupKeys))
    }
}
