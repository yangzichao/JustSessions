import Foundation

/// Like a browser reopening its tabs: the tabs open when the app quit open again at launch, in the same order, with the
/// same one selected. A session tab whose CLI still runs in tmux on this Mac reattaches right away. Any other tab, such
/// as one whose CLI ended with a restart of the Mac, starts once you select it: a session tab resumes its session with
/// the CLI, and a plain terminal opens a new shell in its folder. A New session or Branch tab whose session was never
/// known has nothing to reopen.
extension ConversationStore {
    /// Every open tab with something to reopen, then the tabs from the last quit that have not reopened yet.
    var reopenableTabs: [ReopenableTerminalTab] {
        terminalSessions.compactMap { ReopenableTerminalTab(tab: $0, selectedTerminalID: selectedTerminalID) }
            + pendingTabReopening.waitingTabs.map(\.tab)
    }

    /// As the app quits, before its tabs close.
    func saveTabsForNextLaunch(to tabsSavedAtQuit: TabsSavedAtQuit = .shared) {
        tabsSavedAtQuit.save(reopenableTabs, to: userDefaults)
    }

    /// At launch, before the first refresh.
    func reopenTabsFromLastQuit(
        from tabsSavedAtQuit: TabsSavedAtQuit = .shared,
        isEnabled: Bool = TabReopeningSettingsStore.shared.reopensTabsAtLaunch
    ) {
        let tabs = tabsSavedAtQuit.take(from: userDefaults)
        guard isEnabled else { return }
        beginReopening(tabs)
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
        guard !pendingTabReopening.waitingTabs.isEmpty else { return }
        for waitingTab in pendingTabReopening.takeWaitingTabs(where: shouldReopen) {
            guard let session = makeReopenedTerminal(for: waitingTab.tab) else { continue }
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
