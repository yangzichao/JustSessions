import Foundation

extension ConversationStore {
    /// Called after a complete tab mutation, including linking a newly discovered session to its tab.
    func persistOpenTabs() {
        guard let openTabPersistence, !isRestoringTabBatch, !isTerminatingWorkspace else { return }
        saveTabsForNextLaunch(to: openTabPersistence)
    }

    /// Freeze the recovery snapshot before tearing down the terminal views on normal app termination.
    func prepareTabsForTermination() {
        persistOpenTabs()
        isTerminatingWorkspace = true
        closeAllTerminals()
    }

    /// Closing a workspace window deliberately removes its tabs, without affecting another window's snapshot.
    func closeWorkspace() {
        guard !isTerminatingWorkspace else { return }
        closeAllTerminals()
        openTabPersistence?.removeWindow(tabPersistenceWindowID, from: userDefaults)
        openTabPersistence = nil
    }
}
