import Foundation

/// Moving a tab, or a split's two tabs, from one window's tab bar to another's, as Chrome moves a tab dragged between
/// windows. It leaves its tab bar as a closed tab does, though a split goes whole, and joins the other bar among its
/// group's tabs, or as a new group when that bar has none of its group.
extension TerminalTabStrip {
    /// Takes out `tabIDs`, one of the units `movingUnits(inGroup:)` lists: a tab in no split, or a split's two tabs.
    /// Changes nothing and returns nil for any other set of tabs.
    mutating func takeOutForAnotherWindow(_ tabIDs: [UUID]) -> DetachedTabStripUnit? {
        guard let firstTab = tabs.first(where: { tabIDs.contains($0.id) }),
              let unitTabIDs = movingUnits(inGroup: groupKey(of: firstTab)).first(where: { $0.contains(firstTab.id) }),
              Set(unitTabIDs) == Set(tabIDs) else { return nil }
        let unitTabs = tabs.filter { tabIDs.contains($0.id) }
        let split = split(containing: firstTab.id)
        let groupKey = split.flatMap { split in
            unitTabs.contains { $0.projectKey == split.groupKey } ? split.groupKey : nil
        } ?? firstTab.projectKey
        // Unlinked first, so taking out one of its tabs does not send the other back to its project's tabs.
        self = TerminalTabStrip(tabs: tabs, splits: splits.filter { $0.id != split?.id })
        for tab in unitTabs { removeTab(tab.id) }
        return DetachedTabStripUnit(tabs: unitTabs, split: split, groupKey: groupKey)
    }

    /// Puts tabs taken out of another window's tab bar in this one, at `placement`, with their split, if any, showing
    /// in their group.
    mutating func bringIn(_ unit: DetachedTabStripUnit, at placement: TabStripPlacement) {
        var reorderedTabs = tabs
        // Where a new tab of the group opens, then moved to its place.
        reorderedTabs.insert(
            contentsOf: unit.tabs,
            at: TerminalTabOrder.insertionIndex(forProjectKey: unit.groupKey, amongTabProjectKeys: groupKeys)
        )
        let broughtInSplits = unit.split.map { [$0.regrouped(into: unit.groupKey)] } ?? []
        self = TerminalTabStrip(tabs: reorderedTabs, splits: splits + broughtInSplits)
        guard let firstTab = unit.tabs.first else { return }
        switch placement {
        case .amongGroupTabs(let place):
            moveTab(firstTab.id, toPlaceInGroup: place)
        case .asNewGroup(let place):
            moveGroup(unit.groupKey, toPlace: place)
        }
    }
}
