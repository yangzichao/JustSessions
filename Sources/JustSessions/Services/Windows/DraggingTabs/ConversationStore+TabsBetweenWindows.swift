import Foundation

extension ConversationStore {
    func takeOutTabsForAnotherWindow(_ tabIDs: [UUID]) -> TabsBetweenWindows? {
        var strip = tabStrip
        guard let unit = strip.takeOutForAnotherWindow(tabIDs) else { return nil }
        defer { persistOpenTabs() }
        let tabsByID = Dictionary(uniqueKeysWithValues: terminalSessions.map { ($0.id, $0) })
        let tabs = unit.tabs.compactMap { tabsByID[$0.id] }
        let leavingIDs = Set(tabIDs)
        let tabToSelect =
            selectedTerminalID.map(leavingIDs.contains) == true
            ? tabToSelect(afterTakingOut: leavingIDs)
            : selectedTerminalID
        apply(strip)
        selectTerminal(tabToSelect)
        return TabsBetweenWindows(unit: unit, tabs: tabs)
    }

    func bringInTabsFromAnotherWindow(_ incoming: TabsBetweenWindows, at placement: TabStripPlacement, selecting tabID: UUID) {
        defer { persistOpenTabs() }
        for tab in incoming.tabs {
            showProjectInSidebar(tab.projectDirectoryKey)
            let host = tab.host
            tab.onProcessFinished = { [weak self] in self?.refresh(host) }
            followLightDarkChanges(of: tab)
        }
        var strip = tabStrip
        strip.bringIn(incoming.unit, at: placement)
        apply(strip, bringingIn: incoming.tabs)
        selectTerminal(tabID)
    }

    private func tabToSelect(afterTakingOut leavingIDs: Set<UUID>) -> UUID? {
        guard let firstIndex = terminalSessions.firstIndex(where: { leavingIDs.contains($0.id) }) else { return nil }
        var tabGroupKeys = tabGroupKeys
        var remainingTabIDs = terminalSessions.map(\.id)
        for index in terminalSessions.indices.reversed() where index != firstIndex && leavingIDs.contains(terminalSessions[index].id) {
            tabGroupKeys.remove(at: index)
            remainingTabIDs.remove(at: index)
        }
        remainingTabIDs.remove(at: firstIndex)
        return TerminalTabOrder.indexToSelect(afterClosingTabAt: firstIndex, amongTabProjectKeys: tabGroupKeys)
            .map { remainingTabIDs[$0] }
    }
}
