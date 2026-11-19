import Foundation

extension ConversationStore {
    func moveTab(_ tabID: UUID, toPlaceInGroup place: Int) {
        var strip = tabStrip
        strip.moveTab(tabID, toPlaceInGroup: place)
        guard strip != tabStrip else { return }
        defer { persistOpenTabs() }
        apply(strip)
    }

    func moveTabs(_ tabIDs: [UUID], toPlaceInGroup place: Int) {
        var strip = tabStrip
        strip.moveTabs(tabIDs, toPlaceInGroup: place)
        guard strip != tabStrip else { return }
        defer { persistOpenTabs() }
        apply(strip)
    }

    func moveTabGroup(_ groupKey: String, toPlace place: Int) {
        var strip = tabStrip
        strip.moveGroup(groupKey, toPlace: place)
        guard strip != tabStrip else { return }
        defer { persistOpenTabs() }
        apply(strip)
    }
}
