import Foundation

extension PendingTabReopening {
    func snapshot(openTabs: [(UUID, ReopenableTerminalTab)], hasSelectedOpenTab: Bool) -> [ReopenableTerminalTab] {
        var positions = self
        var result = openTabs
        for waiting in waitingTabs {
            let index = positions.insertionIndex(forSavedPosition: waiting.savedPosition, amongOpenTabIDs: result.map(\.0))
            let placeholderID = UUID()
            let tab = ReopenableTerminalTab(
                conversationID: waiting.tab.conversationID,
                projectDirectoryKey: waiting.tab.projectDirectoryKey,
                wasSelected: waiting.tab.wasSelected && !hasSelectedOpenTab
            )
            result.insert((placeholderID, tab), at: index)
            positions.recordReopenedTab(id: placeholderID, savedPosition: waiting.savedPosition)
        }
        return result.map(\.1)
    }
}
