import Foundation

extension ConversationStore {
    func persistOpenTabs() {
        guard let openTabPersistence, !isSavingOpenTabsOnceAfterChanges, !isTearingDownWorkspace else { return }
        saveTabsForNextLaunch(to: openTabPersistence)
    }

    func savingOpenTabsOnceAfter(_ changes: () -> Void) {
        isSavingOpenTabsOnceAfterChanges = true
        defer {
            isSavingOpenTabsOnceAfterChanges = false
            persistOpenTabs()
        }
        changes()
    }

    func prepareTabsForTermination(reopensTabs: Bool = TabReopeningSettingsStore.shared.reopensTabsAtLaunch) {
        guard !isTearingDownWorkspace else { return }
        cancelThisMacRefresh()
        cancelRemoteHostRefreshes()
        persistOpenTabs()
        isTearingDownWorkspace = true
        if !reopensTabs { endPlainTerminalsBeforeQuitting() }
        closeAllTerminals()
    }

    func closeWorkspace(reopensTabs: Bool = TabReopeningSettingsStore.shared.reopensTabsAtLaunch) {
        guard !isTearingDownWorkspace else { return }
        cancelThisMacRefresh()
        cancelRemoteHostRefreshes()
        persistOpenTabs()
        isTearingDownWorkspace = true
        endPlainTerminalsOfClosingWorkspace(reopensTabs: reopensTabs)
        closeAllTerminals()
        windowRegistry.remove(self)
        resumeQueuedHostWorkInAllWindows()
        openTabPersistence?.closeWindow(tabPersistenceWindowID, in: userDefaults)
        openTabPersistence = nil
    }
}
