import Foundation

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

    var groupKeys: [String] { tabs.map(groupKey(of:)) }

    func split(containing tabID: UUID) -> TerminalSplit? {
        splits.first { $0.contains(tabID) }
    }

    func groupKey(of tab: Tab) -> String {
        split(containing: tab.id)?.groupKey ?? tab.projectKey
    }

    func sides(of split: TerminalSplit) -> TerminalSplit.Sides? {
        let splitTabIDs = tabs.map(\.id).filter(split.contains)
        guard splitTabIDs.count == 2 else { return nil }
        return TerminalSplit.Sides(left: splitTabIDs[0], right: splitTabIDs[1])
    }

    func insertionIndex(forNewTabOfProject projectKey: String) -> Int {
        TerminalTabOrder.insertionIndex(forProjectKey: projectKey, amongTabProjectKeys: groupKeys)
    }

    func insertionIndex(forReopenedTabOfProject projectKey: String, at index: Int) -> Int {
        let index = min(max(index, 0), tabs.count)
        guard index > 0, index < tabs.count else { return index }
        let groupKeys = groupKeys
        let partsASplit = split(containing: tabs[index - 1].id)?.contains(tabs[index].id) == true
        let isAmongAnotherGroup = groupKeys[index - 1] == groupKeys[index] && groupKeys[index] != projectKey
        return partsASplit || isAmongAnotherGroup ? insertionIndex(forNewTabOfProject: projectKey) : index
    }

    @discardableResult
    mutating func addSplit(
        joining joiningID: UUID,
        beside pivotID: UUID,
        on joiningSide: TerminalSplit.JoiningSide = .sideItCameFrom,
        splitID: UUID = UUID(),
        orientation: TerminalSplit.Orientation = .sideBySide
    ) -> TerminalSplit? {
        guard joiningID != pivotID,
            let joiningIndex = index(of: joiningID),
            let pivotIndex = index(of: pivotID),
            split(containing: joiningID) == nil,
            split(containing: pivotID) == nil
        else { return nil }
        let pivotProjectKey = tabs[pivotIndex].projectKey
        let groupKey =
            tabs[joiningIndex].projectKey == pivotProjectKey
            ? pivotProjectKey
            : TerminalSplit.groupKey(ofSplitAcrossProjects: splitID)
        let split = TerminalSplit(id: splitID, tabIDs: (pivotID, joiningID), groupKey: groupKey, orientation: orientation)
        let joiningTab = tabs.remove(at: joiningIndex)
        let pivotIndexAfterRemoval = joiningIndex < pivotIndex ? pivotIndex - 1 : pivotIndex
        let side: TerminalSplit.Side =
            switch joiningSide {
            case .fixed(let side): side
            case .sideItCameFrom: joiningIndex < pivotIndex ? .left : .right
            }
        tabs.insert(joiningTab, at: side == .left ? pivotIndexAfterRemoval : pivotIndexAfterRemoval + 1)
        splits.append(split)
        if split.spansProjects { move(split, afterGroupOf: pivotProjectKey) }
        return split
    }

    mutating func setOrientation(_ orientation: TerminalSplit.Orientation, ofSplit splitID: UUID) {
        guard let splitIndex = splits.firstIndex(where: { $0.id == splitID }) else { return }
        splits[splitIndex].orientation = orientation
    }

    mutating func reverseSplit(_ splitID: UUID) {
        guard let split = splits.first(where: { $0.id == splitID }),
            let sides = sides(of: split),
            let leftIndex = index(of: sides.left),
            let rightIndex = index(of: sides.right)
        else { return }
        tabs.swapAt(leftIndex, rightIndex)
    }

    mutating func separateSplit(_ splitID: UUID) {
        guard let split = splits.first(where: { $0.id == splitID }) else { return }
        splits.removeAll { $0.id == splitID }
        guard let sides = sides(of: split) else { return }
        returnToProjectGroup(sides.left, from: split.groupKey)
        returnToProjectGroup(sides.right, from: split.groupKey)
    }

    mutating func separateAllSplits() {
        for tabID in tabIDs {
            if let split = split(containing: tabID) { separateSplit(split.id) }
        }
    }

    @discardableResult
    mutating func swap(_ incomingID: UUID, intoSplit splitID: UUID, replacing outgoingID: UUID) -> Bool {
        guard incomingID != outgoingID,
            let splitIndex = splits.firstIndex(where: { $0.id == splitID }),
            let stayingID = splits[splitIndex].partner(of: outgoingID),
            split(containing: incomingID) == nil,
            let incomingIndex = index(of: incomingID),
            let outgoingIndex = index(of: outgoingID),
            let stayingIndex = index(of: stayingID)
        else { return false }
        let incomingProjectKey = tabs[incomingIndex].projectKey
        let stayingProjectKey = tabs[stayingIndex].projectKey
        tabs.swapAt(incomingIndex, outgoingIndex)
        splits[splitIndex] = splits[splitIndex].replacing(outgoingID, with: incomingID)
        returnToProjectGroup(outgoingID, from: incomingProjectKey)
        regroup(splitID, besideGroupOf: stayingProjectKey)
        return true
    }

    mutating func removeTab(_ tabID: UUID) {
        guard let index = index(of: tabID) else { return }
        tabs.remove(at: index)
        if let split = split(containing: tabID) {
            splits.removeAll { $0.id == split.id }
            if let partner = split.partner(of: tabID) { returnToProjectGroup(partner, from: split.groupKey) }
        }
    }

    mutating func removeTabsWithoutRegrouping(_ tabIDs: Set<UUID>) {
        tabs.removeAll { tabIDs.contains($0.id) }
        splits.removeAll { split in tabIDs.contains(where: split.contains) }
    }

    private func index(of tabID: UUID) -> Int? {
        tabs.firstIndex { $0.id == tabID }
    }

    private func place(forTabOfProject projectKey: String, nearest index: Int) -> Int {
        let groupKeys = groupKeys
        if let lastTabOfProject = groupKeys.lastIndex(of: projectKey) { return lastTabOfProject + 1 }
        var place = min(max(index, 0), tabs.count)
        while place > 0, place < tabs.count, groupKeys[place - 1] == groupKeys[place] { place += 1 }
        return place
    }

    private mutating func returnToProjectGroup(_ tabID: UUID, from groupKey: String) {
        guard let index = index(of: tabID), tabs[index].projectKey != groupKey else { return }
        let tab = tabs.remove(at: index)
        tabs.insert(tab, at: place(forTabOfProject: tab.projectKey, nearest: index))
    }

    private mutating func move(_ split: TerminalSplit, afterGroupOf projectKey: String) {
        guard let sides = sides(of: split), let leftIndex = index(of: sides.left) else { return }
        let splitTabs = tabs.filter { split.contains($0.id) }
        tabs.removeAll { split.contains($0.id) }
        tabs.insert(contentsOf: splitTabs, at: place(forTabOfProject: projectKey, nearest: leftIndex))
    }

    private mutating func regroup(_ splitID: UUID, besideGroupOf projectKey: String) {
        guard let splitIndex = splits.firstIndex(where: { $0.id == splitID }),
            let sides = sides(of: splits[splitIndex]),
            let left = tabs.first(where: { $0.id == sides.left }),
            let right = tabs.first(where: { $0.id == sides.right })
        else { return }
        let split = splits[splitIndex]
        let groupKey =
            left.projectKey == right.projectKey
            ? left.projectKey
            : TerminalSplit.groupKey(ofSplitAcrossProjects: split.id)
        guard groupKey != split.groupKey else { return }
        splits[splitIndex] = split.regrouped(into: groupKey)
        move(split, afterGroupOf: projectKey)
    }
}
