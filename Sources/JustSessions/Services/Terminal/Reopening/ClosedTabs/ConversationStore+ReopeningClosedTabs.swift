import Foundation

/// Reopen Closed Tab (⇧⌘T), as in Chrome: each time, the latest tab closed in this window comes back at its place in
/// the tab bar, selected. A session tab resumes its session, reattaching to its CLI when that still runs in tmux, and a
/// plain terminal opens a new shell in its folder. A closed tab with nothing left to reopen, such as one whose session
/// is gone or whose host was removed, is passed over for the one closed before it. Tabs that go because their session
/// is deleted, they move to another window, or their host disconnects were not closed by you, so they are not kept.
extension ConversationStore {
    var canReopenClosedTab: Bool { !recentlyClosedTabs.isEmpty }

    func reopenClosedTab() {
        while let closedTab = recentlyClosedTabs.takeLatest() {
            if reopen(closedTab) { return }
        }
    }

    /// Run as a tab closes, with its place in the tab bar. A New session or Branch tab whose session is not known yet
    /// has nothing to reopen.
    func rememberClosedTab(_ tab: TerminalSession, at tabBarIndex: Int) {
        guard !isClosingTabsWithoutRemembering,
            let reopenableTab = ReopenableTerminalTab(tab: tab, selectedTerminalID: nil)
        else { return }
        recentlyClosedTabs.remember(reopenableTab, closedAt: tabBarIndex)
    }

    /// Closes tabs that Reopen Closed Tab should not bring back.
    func closingTabsWithoutRemembering(_ closeTabs: () -> Void) {
        let wasClosingTabsWithoutRemembering = isClosingTabsWithoutRemembering
        isClosingTabsWithoutRemembering = true
        defer { isClosingTabsWithoutRemembering = wasClosingTabsWithoutRemembering }
        closeTabs()
    }

    /// Whether a tab now shows what the closed tab did. Reopening uses its host, so a disconnected one connects again,
    /// as resuming connects it.
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
        // A session runs in one tab across windows, so a tab it has again, here or in another window, comes forward.
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
