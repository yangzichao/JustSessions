import Foundation

/// The tab bar's order and its splits, changed as Chrome's tab strip changes them, worked out on tab ids and project
/// keys alone so the store only applies the result. Every change keeps the order's rules: the tabs of one group sit
/// together, a split's two tabs sit side by side, a split of two tabs of one project shows in that project's group,
/// and a split across two projects shows in neither project's group but as a unit of its own among the groups, under
/// a group key of its own, so neither tab leaves its project for the other's. A tab's group is its split's while it is
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
    /// or at the end with none open. A split across projects is in no project's group, so its tabs count for none.
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
    /// pivot on `joiningSide`, or, without one, on the side it came from: right before it, as the left pane, when it
    /// came from before it in the tab bar, or else right after it, as the right pane. Two tabs of one project split in
    /// their project's group. A split across two projects takes a group key of its own and moves whole to right after
    /// the pivot's project's group, or, when the pivot was its project's only tab, stays where the pivot was, at a
    /// place that parts no group. Changes nothing and returns nil unless both tabs are open, different, and in no split.
    @discardableResult
    mutating func addSplit(
        joining joiningID: UUID,
        beside pivotID: UUID,
        on joiningSide: TerminalSplit.Side? = nil,
        splitID: UUID = UUID(),
        orientation: TerminalSplit.Orientation = .sideBySide
    ) -> TerminalSplit? {
        guard joiningID != pivotID,
              let joiningIndex = index(of: joiningID),
              let pivotIndex = index(of: pivotID),
              split(containing: joiningID) == nil,
              split(containing: pivotID) == nil else { return nil }
        let pivotProjectKey = tabs[pivotIndex].projectKey
        let groupKey = tabs[joiningIndex].projectKey == pivotProjectKey
            ? pivotProjectKey
            : TerminalSplit.groupKey(ofSplitAcrossProjects: splitID)
        let split = TerminalSplit(id: splitID, tabIDs: (pivotID, joiningID), groupKey: groupKey, orientation: orientation)
        let joiningTab = tabs.remove(at: joiningIndex)
        let pivotIndexAfterRemoval = joiningIndex < pivotIndex ? pivotIndex - 1 : pivotIndex
        let side = joiningSide ?? (joiningIndex < pivotIndex ? .left : .right)
        tabs.insert(joiningTab, at: side == .left ? pivotIndexAfterRemoval : pivotIndexAfterRemoval + 1)
        splits.append(split)
        if split.spansProjects { move(split, afterGroupOf: pivotProjectKey) }
        return split
    }

    /// Lays the split's two views out as `orientation`; the tabs keep their places.
    mutating func setOrientation(_ orientation: TerminalSplit.Orientation, ofSplit splitID: UUID) {
        guard let splitIndex = splits.firstIndex(where: { $0.id == splitID }) else { return }
        splits[splitIndex].orientation = orientation
    }

    /// The split's two tabs trade places in the tab bar, so its panes trade sides, as Chrome's ReverseTabsInSplit.
    mutating func reverseSplit(_ splitID: UUID) {
        guard let split = splits.first(where: { $0.id == splitID }),
              let sides = sides(of: split),
              let leftIndex = index(of: sides.left),
              let rightIndex = index(of: sides.right) else { return }
        tabs.swapAt(leftIndex, rightIndex)
    }

    /// Unlinks the split, as Chrome's RemoveSplit. Each tab is in its own project's group again: the two tabs of a
    /// split across projects each go back to their project's tabs, as a new tab of the project would open, or stay
    /// between the groups when their project has no other tab in one.
    mutating func separateSplit(_ splitID: UUID) {
        guard let split = splits.first(where: { $0.id == splitID }) else { return }
        splits.removeAll { $0.id == splitID }
        guard let sides = sides(of: split) else { return }
        returnToProjectGroup(sides.left, from: split.groupKey)
        returnToProjectGroup(sides.right, from: split.groupKey)
    }

    /// Separates every split, from the first in the tab bar to the last.
    mutating func separateAllSplits() {
        for tabID in tabIDs {
            if let split = split(containing: tabID) { separateSplit(split.id) }
        }
    }

    /// Swaps the tab `incomingID`, in no split, into the split in the place of its tab `outgoingID`, as Chrome's
    /// UpdateTabInSplit with kSwap: the two trade places in the tab bar, the incoming tab joining the split, which
    /// keeps its id, and the outgoing one leaving it. The outgoing tab then sits in the incoming tab's project group;
    /// when its own project is another, it goes back to its project's tabs. The split keeps its group while the
    /// incoming tab is of the same project as the one it replaces. Otherwise it is now of one project, and moves to
    /// that project's group, or now across two, and moves to right after the group of the tab that stayed; see
    /// `move(_:afterGroupOf:)`. Returns whether the swap was made.
    @discardableResult
    mutating func swap(_ incomingID: UUID, intoSplit splitID: UUID, replacing outgoingID: UUID) -> Bool {
        guard incomingID != outgoingID,
              let splitIndex = splits.firstIndex(where: { $0.id == splitID }),
              let stayingID = splits[splitIndex].partner(of: outgoingID),
              split(containing: incomingID) == nil,
              let incomingIndex = index(of: incomingID),
              let outgoingIndex = index(of: outgoingID),
              let stayingIndex = index(of: stayingID) else { return false }
        let incomingProjectKey = tabs[incomingIndex].projectKey
        let stayingProjectKey = tabs[stayingIndex].projectKey
        tabs.swapAt(incomingIndex, outgoingIndex)
        splits[splitIndex] = splits[splitIndex].replacing(outgoingID, with: incomingID)
        returnToProjectGroup(outgoingID, from: incomingProjectKey)
        regroup(splitID, besideGroupOf: stayingProjectKey)
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
    }

    // MARK: - Helpers

    private func index(of tabID: UUID) -> Int? {
        tabs.firstIndex { $0.id == tabID }
    }

    /// Where a tab of the project goes as it leaves a group not its own: right after the last tab in its project's
    /// group, or, with no tab of its project in a group, the nearest place at or after `index` that parts no group.
    private func place(forTabOfProject projectKey: String, nearest index: Int) -> Int {
        let groupKeys = groupKeys
        if let lastTabOfProject = groupKeys.lastIndex(of: projectKey) { return lastTabOfProject + 1 }
        var place = min(max(index, 0), tabs.count)
        while place > 0, place < tabs.count, groupKeys[place - 1] == groupKeys[place] { place += 1 }
        return place
    }

    /// Moves a tab in no split that sits in the group `groupKey` to its project's place, unless that group is its
    /// project's; see `place(forTabOfProject:nearest:)`.
    private mutating func returnToProjectGroup(_ tabID: UUID, from groupKey: String) {
        guard let index = index(of: tabID), tabs[index].projectKey != groupKey else { return }
        let tab = tabs.remove(at: index)
        tabs.insert(tab, at: place(forTabOfProject: tab.projectKey, nearest: index))
    }

    /// Moves the split's two tabs, in their order, to right after the last tab in the group of `projectKey`, or, with
    /// no tab of that project in a group, to the nearest place at or after where they sit that parts no group.
    private mutating func move(_ split: TerminalSplit, afterGroupOf projectKey: String) {
        guard let sides = sides(of: split), let leftIndex = index(of: sides.left) else { return }
        let splitTabs = tabs.filter { split.contains($0.id) }
        tabs.removeAll { split.contains($0.id) }
        tabs.insert(contentsOf: splitTabs, at: place(forTabOfProject: projectKey, nearest: leftIndex))
    }

    /// Gives the split the group its two tabs call for once one of them changed: their project's, when both are of
    /// one, or else a group of its own. A split whose group changes moves beside the group of `projectKey`, the
    /// project of the tab that stayed; see `move(_:afterGroupOf:)`.
    private mutating func regroup(_ splitID: UUID, besideGroupOf projectKey: String) {
        guard let splitIndex = splits.firstIndex(where: { $0.id == splitID }),
              let sides = sides(of: splits[splitIndex]),
              let left = tabs.first(where: { $0.id == sides.left }),
              let right = tabs.first(where: { $0.id == sides.right }) else { return }
        let split = splits[splitIndex]
        let groupKey = left.projectKey == right.projectKey
            ? left.projectKey
            : TerminalSplit.groupKey(ofSplitAcrossProjects: split.id)
        guard groupKey != split.groupKey else { return }
        splits[splitIndex] = split.regrouped(into: groupKey)
        move(split, afterGroupOf: projectKey)
    }
}
