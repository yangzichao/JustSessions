import Foundation

extension TerminalTabStrip {
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

    var groupKeysInOrder: [String] {
        TerminalTabGroup.groups(of: tabs, projectDirectoryKey: groupKey(of:)).map(\.projectDirectoryKey)
    }

    mutating func moveTab(_ tabID: UUID, toPlaceInGroup place: Int) {
        guard let tab = tabs.first(where: { $0.id == tabID }),
            let unit = movingUnits(inGroup: groupKey(of: tab)).first(where: { $0.contains(tabID) })
        else { return }
        moveTabs(unit, toPlaceInGroup: place)
    }

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
        reorderedTabs.replaceSubrange(groupStart..<groupStart + groupTabs.count, with: groupTabs)
        self = TerminalTabStrip(tabs: reorderedTabs, splits: splits)
    }

    mutating func moveGroup(_ group: String, toPlace place: Int) {
        var groups = TerminalTabGroup.groups(of: tabs, projectDirectoryKey: groupKey(of:))
        guard let groupIndex = groups.firstIndex(where: { $0.projectDirectoryKey == group }) else { return }
        let movedGroup = groups.remove(at: groupIndex)
        groups.insert(movedGroup, at: min(max(place, 0), groups.count))
        self = TerminalTabStrip(tabs: groups.flatMap(\.tabs), splits: splits)
    }
}
