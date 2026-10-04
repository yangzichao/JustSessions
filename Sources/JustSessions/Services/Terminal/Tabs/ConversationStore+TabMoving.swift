import Foundation

/// Dragging tabs and groups in the tab bar; see `TerminalTabStrip` for how they may move. The selection stays.
extension ConversationStore {
    /// Moves the tab, with the other tab of its split, to `place` among its group's tabs and splits.
    func moveTab(_ tabID: UUID, toPlaceInGroup place: Int) {
        var strip = tabStrip
        strip.moveTab(tabID, toPlaceInGroup: place)
        guard strip != tabStrip else { return }
        defer { persistOpenTabs() }
        apply(strip)
    }

    /// Moves the group's tabs, in their order, to `place` among the groups.
    func moveTabGroup(_ groupKey: String, toPlace place: Int) {
        var strip = tabStrip
        strip.moveGroup(groupKey, toPlace: place)
        guard strip != tabStrip else { return }
        defer { persistOpenTabs() }
        apply(strip)
    }
}
