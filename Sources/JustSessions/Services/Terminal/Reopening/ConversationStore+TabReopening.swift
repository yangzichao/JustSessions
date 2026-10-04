import Foundation

/// Like a browser reopening its tabs: the tabs open when the app quit open again at launch, in the same order, with the
/// same one selected. A session tab whose CLI still runs in tmux on this Mac reattaches right away. Any other tab, such
/// as one whose CLI ended with a restart of the Mac, starts once you select it: a session tab resumes its session with
/// the CLI, and a plain terminal opens a new shell in its folder. A New session or Branch tab whose session was never
/// known has nothing to reopen.
extension ConversationStore {
    /// Every open tab with something to reopen, then the tabs from the last quit that have not reopened yet.
    var reopenableTabs: [ReopenableTerminalTab] {
        let openTabs = terminalSessions.compactMap { terminal -> (UUID, ReopenableTerminalTab)? in
            guard let tab = ReopenableTerminalTab(tab: terminal, selectedTerminalID: selectedTerminalID) else { return nil }
            return (terminal.id, tab)
        }
        return pendingTabReopening.snapshot(openTabs: openTabs, hasSelectedOpenTab: selectedTerminalID != nil)
    }

    /// Replace this window's part of the recovery snapshot, including tabs still waiting for a host.
    func saveTabsForNextLaunch(to persistence: OpenTabPersistence = .shared) {
        persistence.update(reopenableTabs, for: tabPersistenceWindowID, in: userDefaults)
    }

    /// At launch, before the first refresh.
    func reopenTabsFromLastQuit(
        from persistence: OpenTabPersistence = .shared,
        isEnabled: Bool = TabReopeningSettingsStore.shared.reopensTabsAtLaunch
    ) {
        guard openTabPersistence == nil else { return }
        // The packaged launch check explicitly disables reopening through launch arguments. That disposable
        // process must not replace the user's recovery snapshot with its empty workspace.
        guard userDefaults.volatileDomain(forName: UserDefaults.argumentDomain)[TabReopeningSettingsStore.userDefaultsKey] as? Bool != false else { return }
        let tabs = persistence.take(from: userDefaults)
        openTabPersistence = persistence
        beginReopening(isEnabled ? tabs : [])
    }

    /// Plain terminals reopen right away. Session tabs wait for their host to list its sessions; a host no longer in
    /// the host list never will, so its tabs are left out.
    func beginReopening(_ tabs: [ReopenableTerminalTab]) {
        let listedHosts = Set(hosts)
        pendingTabReopening = PendingTabReopening(tabs: tabs.filter { listedHosts.contains($0.host) })
        reopenWaitingTabs { $0.isPlainTerminal }
    }

    /// Once the host lists its sessions, its waiting tabs reopen, except those whose session is gone.
    func reopenWaitingTabs(on host: SessionHost) {
        reopenWaitingTabs { $0.host == host }
    }

    private func reopenWaitingTabs(where shouldReopen: (ReopenableTerminalTab) -> Bool) {
        // Save only after the entire batch; intermediate inserts must not drop the other waiting tabs.
        isRestoringTabBatch = true
        defer {
            isRestoringTabBatch = false
            persistOpenTabs()
        }
        for waitingTab in pendingTabReopening.takeWaitingTabs(where: shouldReopen) {
            guard let session = makeReopenedTerminal(for: waitingTab.tab) else {
                if let conversationID = waitingTab.tab.conversationID,
                   conversation(withID: conversationID) != nil,
                   !terminalSessions.contains(where: { $0.conversation?.id == conversationID }) {
                    // A missing CLI or temporarily unavailable project can become usable on a later refresh.
                    pendingTabReopening.returnWaitingTab(waitingTab)
                }
                continue
            }
            let index = pendingTabReopening.insertionIndex(
                forSavedPosition: waitingTab.savedPosition,
                amongOpenTabIDs: terminalSessions.map(\.id)
            )
            pendingTabReopening.recordReopenedTab(id: session.id, savedPosition: waitingTab.savedPosition)
            // A tab selected since launch stays selected.
            insertReopenedTerminal(session, at: index, selecting: waitingTab.tab.wasSelected && selectedTerminalID == nil)
        }
    }

    /// Nil when the session is no longer listed or already has a tab, or when the folder is gone.
    private func makeReopenedTerminal(for tab: ReopenableTerminalTab) -> TerminalSession? {
        guard let conversationID = tab.conversationID else {
            return try? makePlainTerminal(in: ProjectLocation(key: tab.projectDirectoryKey), startsOnceShown: true)
        }
        guard let conversation = conversation(withID: conversationID),
              canLaunch(conversation, action: .resume),
              runningTerminal(for: conversation) == nil else { return nil }
        // Reattaching costs nothing, and lets the tab report what the CLI does from the start.
        let reattachesNow = conversation.host == .thisMac && isRunningInTmux(conversation)
        return try? makeTerminal(for: conversation, action: .resume, startsOnceShown: !reattachesNow)
    }
}
