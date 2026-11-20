import Foundation

extension ConversationStore {
    var reopenableTabs: [ReopenableTerminalTab] {
        let openTabs = terminalSessionsWithSplitsSeparated.compactMap { terminal -> (UUID, ReopenableTerminalTab)? in
            guard let tab = ReopenableTerminalTab(tab: terminal, selectedTerminalID: selectedTerminalID) else { return nil }
            return (terminal.id, tab)
        }
        return pendingTabReopening.snapshot(openTabs: openTabs, hasSelectedOpenTab: selectedTerminalID != nil)
    }

    func saveTabsForNextLaunch(to persistence: OpenTabPersistence = .shared) {
        persistence.update(reopenableTabs, for: tabPersistenceWindowID, in: userDefaults)
    }

    func reopenTabsFromLastQuit(
        from persistence: OpenTabPersistence = .shared,
        isEnabled: Bool = TabReopeningSettingsStore.shared.reopensTabsAtLaunch
    ) {
        guard openTabPersistence == nil else { return }
        guard !TabReopeningSettingsStore.isTurnedOffByLaunchArgument(in: userDefaults) else { return }
        let tabs = persistence.take(from: userDefaults)
        openTabPersistence = persistence
        beginReopening(isEnabled ? tabs : [])
    }

    func beginReopening(_ tabs: [ReopenableTerminalTab]) {
        let listedHosts = Set(hosts)
        pendingTabReopening = PendingTabReopening(tabs: tabs.filter { listedHosts.contains($0.host) && !isDisconnected($0.host) })
        reopenWaitingTabs { $0.isPlainTerminal && $0.host != .thisMac }
    }

    func reopenWaitingTabs(on host: SessionHost, discardMissingSessions: Bool = true) {
        reopenWaitingTabs { tab in
            guard tab.host == host else { return false }
            guard !discardMissingSessions, let conversationID = tab.conversationID else { return true }
            return conversation(withID: conversationID) != nil
        }
    }

    private func reopenWaitingTabs(where shouldReopen: (ReopenableTerminalTab) -> Bool) {
        savingOpenTabsOnceAfter {
            for waitingTab in pendingTabReopening.takeWaitingTabs(where: shouldReopen) {
                reopenWaitingTab(waitingTab)
            }
        }
    }

    private func reopenWaitingTab(_ waitingTab: PendingTabReopening.WaitingTab) {
        guard let session = makeReopenedTerminal(for: waitingTab.tab) else {
            if let conversationID = waitingTab.tab.conversationID,
                let conversation = conversation(withID: conversationID),
                !terminalSessions.contains(where: { $0.conversation?.id == conversationID }),
                runningTerminalInAnotherWindow(for: conversation) == nil
            {
                pendingTabReopening.returnWaitingTab(waitingTab)
            }
            return
        }
        let index = pendingTabReopening.insertionIndex(
            forSavedPosition: waitingTab.savedPosition,
            amongOpenTabIDs: terminalSessions.map(\.id)
        )
        pendingTabReopening.recordReopenedTab(id: session.id, savedPosition: waitingTab.savedPosition)
        insertReopenedTerminal(session, at: index, selecting: waitingTab.tab.wasSelected && selectedTerminalID == nil)
    }

    private func makeReopenedTerminal(for tab: ReopenableTerminalTab) -> TerminalSession? {
        guard let conversationID = tab.conversationID else {
            let reattachesNow =
                tab.host == .thisMac
                && tab.tmuxSessionName.map { tmuxSessionNamesByHost[.thisMac]?.contains($0) == true } == true
            return try? makePlainTerminal(
                in: ProjectLocation(key: tab.projectDirectoryKey),
                tmuxSessionName: tab.tmuxSessionName,
                startsOnceShown: !reattachesNow
            )
        }
        guard let conversation = conversation(withID: conversationID),
            canLaunch(conversation, action: .resume),
            runningTerminal(for: conversation) == nil,
            runningTerminalInAnotherWindow(for: conversation) == nil
        else { return nil }
        let reattachesNow = conversation.host == .thisMac && isRunningInTmux(conversation)
        return try? makeTerminal(for: conversation, action: .resume, startsOnceShown: !reattachesNow)
    }
}
