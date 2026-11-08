import Foundation

/// The notification bell in the sidebar header lists every session whose CLI waits on you, as the Waiting for you
/// filter counts them: tabs in every window, and this Mac's CLIs in tmux with no tab open, except a tab whose terminal
/// shows in its window. Unlike notifications, it lists them while the app is in front, and whatever Settings → General
/// turns off.
extension ConversationStore {
    /// Times each wait, after the activity sync has updated the unseen marks.
    func noteWaitingForYouStartTimes(after observations: [SessionActivityObservation], at now: Date = .now) {
        var next = waitingForYouStartTimes
        next.update(after: observations, unseenFinishedTurns: unseenFinishedTurns, at: now)
        guard next != waitingForYouStartTimes else { return }
        waitingForYouStartTimes = next
    }

    /// The bell's rows, the wait that started last first.
    var notificationBellEntries: [NotificationBellEntry] {
        let tabEntries = ([self] + otherWindowStores).flatMap { store in
            let terminalIDsOnScreen = store.terminalIDsOnScreen
            return store.terminalSessions.compactMap { tab in
                terminalIDsOnScreen.contains(tab.id) ? nil : store.notificationBellEntry(for: tab)
            }
        }
        let conversationIDsWithRunningTab = Set(([self] + otherWindowStores).flatMap { store in
            store.terminalSessions.filter(\.isRunning).compactMap { $0.conversation?.id }
        })
        // Until the next activity sync, a CLI just reattached to in a tab is still listed as running with no tab.
        let detachedEntries = detachedCLIActivities.keys
            .filter { !conversationIDsWithRunningTab.contains($0) }
            .compactMap(notificationBellEntry(forDetachedConversationID:))
        return (tabEntries + detachedEntries).sortedNewestFirst()
    }

    /// Shows the session as clicking its notification does, except that a CLI in tmux with no tab open reattaches in
    /// this window.
    func showSession(fromNotificationBell entry: NotificationBellEntry) {
        windowRegistry.showSession(wantingAttention: entry.source, reattachingIn: self)
    }

    /// Nil unless the tab's CLI runs and waits on you.
    private func notificationBellEntry(for tab: TerminalSession) -> NotificationBellEntry? {
        guard tab.isRunning, let provider = tab.provider, let reason = WaitingForYou.reason(
            activity: tab.cliActivity,
            hasUnseenFinishedTurn: tab.hasUnseenFinishedTurn
        ) else { return nil }
        return NotificationBellEntry(
            source: tab.attentionSource,
            reason: reason,
            waitingSince: waitingForYouStartTimes.startTime(of: tab.attentionSource),
            sessionTitle: tab.displayTitle,
            provider: provider,
            projectName: projectDisplayName(forProjectPath: tab.projectDirectoryKey)
        )
    }

    /// Nil unless the session's CLI, which runs in tmux with no tab open, waits on you. A hidden CLI's session is
    /// listed only from an open tab.
    private func notificationBellEntry(forDetachedConversationID conversationID: String) -> NotificationBellEntry? {
        guard let conversation = conversation(withID: conversationID),
              !hiddenConversationProviders.hides(conversation.provider), let reason = WaitingForYou.reason(
            activity: detachedCLIActivities[conversationID],
            hasUnseenFinishedTurn: hasUnseenFinishedTurn(detachedConversationID: conversationID)
        ) else { return nil }
        let source = SessionAttentionSource.detachedTmux(conversationID: conversationID)
        return NotificationBellEntry(
            source: source,
            reason: reason,
            waitingSince: waitingForYouStartTimes.startTime(of: source),
            sessionTitle: title(for: conversation),
            provider: conversation.provider,
            projectName: projectDisplayName(forProjectPath: conversation.projectDirectoryKey)
        )
    }
}
