import Foundation

extension ConversationStore {
    /// Called after a complete tab mutation, including linking a newly discovered session to its tab.
    func persistOpenTabs() {
        guard let openTabPersistence, !isRestoringTabBatch, !isTearingDownWorkspace else { return }
        saveTabsForNextLaunch(to: openTabPersistence)
    }

    /// Freeze the recovery snapshot before tearing down the terminal views on normal app termination. With Reopen tabs
    /// off, nothing reattaches to a plain terminal's shell, so it ends. The app delegate calls this for every window
    /// before the SSH logins end, which the hosts' tmux is reached through; each window's own call then does nothing.
    func prepareTabsForTermination(reopensTabs: Bool = TabReopeningSettingsStore.shared.reopensTabsAtLaunch) {
        guard !isTearingDownWorkspace else { return }
        cancelThisMacRefresh()
        persistOpenTabs()
        isTearingDownWorkspace = true
        if !reopensTabs { endPlainTerminalsBeforeQuitting() }
        closeAllTerminals()
    }

    /// Closing a workspace window removes its tabs, without affecting another window's snapshot. The last window's
    /// tabs stay saved, so opening the app again reopens them; session CLIs keep running in tmux meanwhile, and so do
    /// plain terminals' shells, unless their tabs are dropped for good.
    func closeWorkspace(reopensTabs: Bool = TabReopeningSettingsStore.shared.reopensTabsAtLaunch) {
        guard !isTearingDownWorkspace else { return }
        cancelThisMacRefresh()
        persistOpenTabs()
        isTearingDownWorkspace = true
        endPlainTerminalsOfClosingWorkspace(reopensTabs: reopensTabs)
        closeAllTerminals()
        windowRegistry.remove(self)
        openTabPersistence?.closeWindow(tabPersistenceWindowID, in: userDefaults)
        openTabPersistence = nil
    }
}
