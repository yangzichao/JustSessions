import Foundation

extension ConversationStore {
    /// Called after a complete tab mutation, including linking a newly discovered session to its tab.
    func persistOpenTabs() {
        guard let openTabPersistence, !isRestoringTabBatch, !isTearingDownWorkspace else { return }
        saveTabsForNextLaunch(to: openTabPersistence)
    }

    /// Freeze the recovery snapshot before tearing down the terminal views on normal app termination.
    func prepareTabsForTermination() {
        persistOpenTabs()
        isTearingDownWorkspace = true
        closeAllTerminals()
    }

    /// Closing a workspace window removes its tabs, without affecting another window's snapshot. The last window's
    /// tabs stay saved, so opening the app again reopens them; session CLIs keep running in tmux meanwhile.
    func closeWorkspace() {
        guard !isTearingDownWorkspace else { return }
        persistOpenTabs()
        isTearingDownWorkspace = true
        closeAllTerminals()
        openTabPersistence?.closeWindow(tabPersistenceWindowID, in: userDefaults)
        openTabPersistence = nil
    }
}
