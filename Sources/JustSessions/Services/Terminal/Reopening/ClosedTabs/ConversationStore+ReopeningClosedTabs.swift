import Foundation

extension ConversationStore {
    var canReopenClosedTab: Bool { !recentlyClosedTabs.isEmpty }

    func reopenClosedTab() {
        while let closedTab = recentlyClosedTabs.takeLatest() {
            if reopen(closedTab) { return }
        }
    }

    func rememberClosedTab(_ tab: TerminalSession, at tabBarIndex: Int) {
        guard !isClosingTabsWithoutRemembering,
            let reopenableTab = ReopenableTerminalTab(tab: tab, selectedTerminalID: nil)
        else { return }
        recentlyClosedTabs.remember(reopenableTab, closedAt: tabBarIndex)
    }

    func closingTabsWithoutRemembering(_ closeTabs: () -> Void) {
        let wasClosingTabsWithoutRemembering = isClosingTabsWithoutRemembering
        isClosingTabsWithoutRemembering = true
        defer { isClosingTabsWithoutRemembering = wasClosingTabsWithoutRemembering }
        closeTabs()
    }

    private func reopen(_ closedTab: RecentlyClosedTabs.ClosedTab) -> Bool {
        let tab = closedTab.tab
        guard hosts.contains(tab.host) else { return false }
        guard let conversationID = tab.conversationID else {
            connectIfDisconnected(tab.host)
            guard let terminal = try? makePlainTerminal(in: ProjectLocation(key: tab.projectDirectoryKey)) else { return false }
            insertReopenedTerminal(terminal, at: closedTab.tabBarIndex, selecting: true)
            return true
        }
        guard let conversation = conversation(withID: conversationID), canLaunch(conversation, action: .resume) else { return false }
        if terminalSessions.contains(where: { $0.conversation?.id == conversationID }) || hasTerminalInAnotherWindow(for: conversation) {
            launch(conversation, action: .resume)
            return true
        }
        connectIfDisconnected(conversation.host)
        guard let terminal = try? makeTerminal(for: conversation, action: .resume) else { return false }
        insertReopenedTerminal(terminal, at: closedTab.tabBarIndex, selecting: true)
        return true
    }
}
