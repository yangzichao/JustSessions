import Foundation

/// Moving tabs by dragging them in the tab bar, within the order's rules: a tab moves only among its own group's tabs,
/// a split's two tabs move together, and a group moves whole among the groups.
extension TerminalTabStrip {
    /// The group's tabs as they move, in tab bar order: each tab in no split alone, and a split's two tabs together, so
    /// the split stays whole.
    func movingUnits(inGroup group: String) -> [[UUID]] {
        var units: [[UUID]] = []
        for tab in tabs where groupKey(of: tab) == group {
            if let partner = split(containing: tab.id)?.partner(of: tab.id), units.last == [partner] {
                units[units.count - 1].append(tab.id)
            } else {
                units.append([tab.id])
            }
        }
        return units
    }

    /// Every group's key, in tab bar order.
    var groupKeysInOrder: [String] {
        TerminalTabGroup.groups(of: tabs, projectDirectoryKey: groupKey(of:)).map(\.projectDirectoryKey)
    }

    /// Moves the tab, with the other tab of its split, to `place` among its group's moving units, counted as they sit
    /// once it has left its own place. Its group stays where it is.
    mutating func moveTab(_ tabID: UUID, toPlaceInGroup place: Int) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        let group = groupKey(of: tab)
        var units = movingUnits(inGroup: group)
        guard let unitIndex = units.firstIndex(where: { $0.contains(tabID) }),
              let groupStart = tabs.firstIndex(where: { groupKey(of: $0) == group }) else { return }
        let unit = units.remove(at: unitIndex)
        units.insert(unit, at: min(max(place, 0), units.count))
        let tabsByID = Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, $0) })
        let groupTabs = units.joined().compactMap { tabsByID[$0] }
        var reorderedTabs = tabs
        // A group's tabs sit together, so they fill the range from its first tab on.
        reorderedTabs.replaceSubrange(groupStart..<groupStart + groupTabs.count, with: groupTabs)
        self = TerminalTabStrip(tabs: reorderedTabs, splits: splits)
    }

    /// Moves the group's tabs, in their order, to `place` among the groups, counted as they sit once it has left its
    /// own place.
    mutating func moveGroup(_ group: String, toPlace place: Int) {
        var groups = TerminalTabGroup.groups(of: tabs, projectDirectoryKey: groupKey(of:))
        guard let groupIndex = groups.firstIndex(where: { $0.projectDirectoryKey == group }) else { return }
        let movedGroup = groups.remove(at: groupIndex)
        groups.insert(movedGroup, at: min(max(place, 0), groups.count))
        self = TerminalTabStrip(tabs: groups.flatMap(\.tabs), splits: splits)
    }
}
