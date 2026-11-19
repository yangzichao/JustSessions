import Foundation

/// Moving tabs by dragging them in the tab bar, within the order's rules: a tab moves only among its own group's tabs,
/// a split's two tabs move together, and a group moves whole among the groups, or among another window's tabs of its
/// project once dragged there.
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

    /// The group's moving units, with every unit whose tabs are all in `tabIDs` joined into one, at the first one's
    /// place, as when a whole group dragged from another window joins this window's tabs of its project.
    func movingUnits(inGroup group: String, keepingTogether tabIDs: [UUID]) -> [[UUID]] {
        var units: [[UUID]] = []
        var keptTogetherIndex: Int?
        for unit in movingUnits(inGroup: group) {
            guard unit.allSatisfy(tabIDs.contains) else {
                units.append(unit)
                continue
            }
            if let keptTogetherIndex {
                units[keptTogetherIndex] += unit
            } else {
                keptTogetherIndex = units.count
                units.append(unit)
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
        guard let tab = tabs.first(where: { $0.id == tabID }),
            let unit = movingUnits(inGroup: groupKey(of: tab)).first(where: { $0.contains(tabID) })
        else { return }
        moveTabs(unit, toPlaceInGroup: place)
    }

    /// Moves the tabs, whole moving units of one group, together in their order to `place` among the group's other
    /// moving units, counted as they sit once the tabs have left their place. Their group stays where it is.
    mutating func moveTabs(_ tabIDs: [UUID], toPlaceInGroup place: Int) {
        guard let firstTab = tabs.first(where: { tabIDs.contains($0.id) }) else { return }
        let group = groupKey(of: firstTab)
        var units = movingUnits(inGroup: group, keepingTogether: tabIDs)
        guard let unitIndex = units.firstIndex(where: { $0.contains(firstTab.id) }),
            let groupStart = tabs.firstIndex(where: { groupKey(of: $0) == group })
        else { return }
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
