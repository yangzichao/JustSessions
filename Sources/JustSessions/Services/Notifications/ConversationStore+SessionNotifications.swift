import Foundation

/// Notifies you when a CLI on this Mac finishes its turn or stops to wait on you, unless its tab is in view, and
/// shows that session when you click the notification. The CLI activity sync reports what each CLI does.
extension ConversationStore {
    func notifyOfSessionsWantingAttention(after observations: [SessionActivityObservation]) {
        for event in sessionAttentionTracker.events(after: observations) where !isInView(event.source) {
            guard let notification = sessionNotification(for: event) else { continue }
            sessionNotifier.notify(notification)
        }
    }

    /// Selects the tab that runs the session, if this window has one.
    func showTab(notifiedAbout source: SessionAttentionSource) -> Bool {
        guard let tab = runningTab(for: source) else { return false }
        selectTerminal(tab.id)
        return true
    }

    /// Opens a new tab on the session's CLI, which runs in tmux with no tab open.
    func reattach(notifiedAbout source: SessionAttentionSource) {
        guard let conversationID = source.conversationID, let conversation = conversation(withID: conversationID) else { return }
        showRunningCLI(for: conversation)
    }

    /// The app is in front with the CLI's tab selected.
    private func isInView(_ source: SessionAttentionSource) -> Bool {
        guard let tabID = source.tabID else { return false }
        return sessionNotifier.isApplicationActive && selectedTerminalID == tabID
    }

    /// The tab the source names, or else a tab opened on the same session since, such as by reattaching.
    private func runningTab(for source: SessionAttentionSource) -> TerminalSession? {
        let runningTabs = terminalSessions.filter { !$0.hasExited }
        if let tabID = source.tabID, let tab = runningTabs.first(where: { $0.id == tabID }) { return tab }
        guard let conversationID = source.conversationID else { return nil }
        return runningTabs.first { $0.conversation?.id == conversationID }
    }

    private func sessionNotification(for event: SessionAttentionEvent) -> SessionNotification? {
        if let tab = runningTab(for: event.source), let provider = tab.provider {
            return SessionNotification(
                source: event.source,
                reason: event.reason,
                sessionTitle: tab.displayTitle,
                provider: provider,
                projectName: projectDisplayName(forProjectPath: tab.projectDirectoryKey)
            )
        }
        guard let conversationID = event.source.conversationID, let conversation = conversation(withID: conversationID) else {
            return nil
        }
        return SessionNotification(
            source: event.source,
            reason: event.reason,
            sessionTitle: title(for: conversation),
            provider: conversation.provider,
            projectName: projectDisplayName(forProjectPath: conversation.projectDirectoryKey)
        )
    }
}
