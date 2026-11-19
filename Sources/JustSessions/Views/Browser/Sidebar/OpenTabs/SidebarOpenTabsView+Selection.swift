import SwiftUI

extension SidebarOpenTabsView {
    var visibleTabIDs: [UUID] {
        let groups = TerminalTabGroup.groups(of: matchingTabs, projectDirectoryKey: \.projectDirectoryKey)
        return groupCollapse.tabsInSight(of: groups, whileSearching: isSearching).map(\.id)
    }

    func isHighlighted(_ tabID: UUID) -> Bool {
        selection.isEmpty ? store.selectedTerminalID == tabID : selection.contains(tabID)
    }

    func handleRowClick(_ tabID: UUID) {
        let modifiers = NSEvent.modifierFlags
        guard modifiers.contains(.shift) || modifiers.contains(.command) else {
            onSelectTab(tabID)
            return
        }
        isListFocused = true
        let visibleTabIDs = visibleTabIDs
        let shownTabID = store.selectedTerminalID.flatMap { visibleTabIDs.contains($0) ? $0 : nil }
        selection.selectShownTabWhileNothingIsSelected(shownTabID)
        if modifiers.contains(.shift) {
            selection.selectRange(to: tabID, in: visibleTabIDs)
        } else {
            selection.toggle(tabID)
        }
    }
}
