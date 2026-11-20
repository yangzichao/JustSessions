import Foundation

extension TerminalTabStrip {
    mutating func takeOutForAnotherWindow(_ tabIDs: [UUID]) -> DetachedTabStripUnit? {
        guard let firstTab = tabs.first(where: { tabIDs.contains($0.id) }) else { return nil }
        let groupKey = groupKey(of: firstTab)
        let touchedUnits = movingUnits(inGroup: groupKey).filter { $0.contains(where: tabIDs.contains) }
        guard Set(touchedUnits.joined()) == Set(tabIDs) else { return nil }
        let leavingTabs = tabs.filter { tabIDs.contains($0.id) }
        let leavingSplits = splits.filter { split in leavingTabs.contains { split.contains($0.id) } }
        removeTabsWithoutRegrouping(Set(tabIDs))
        return DetachedTabStripUnit(tabs: leavingTabs, splits: leavingSplits, groupKey: groupKey)
    }

    mutating func bringIn(_ unit: DetachedTabStripUnit, at placement: TabStripPlacement) {
        var reorderedTabs = tabs
        reorderedTabs.insert(
            contentsOf: unit.tabs,
            at: TerminalTabOrder.insertionIndex(forProjectKey: unit.groupKey, amongTabProjectKeys: groupKeys)
        )
        self = TerminalTabStrip(tabs: reorderedTabs, splits: splits + unit.splits)
        switch placement {
        case .amongGroupTabs(let place):
            moveTabs(unit.tabs.map(\.id), toPlaceInGroup: place)
        case .asNewGroup(let place):
            moveGroup(unit.groupKey, toPlace: place)
        }
    }
}
