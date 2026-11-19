import Foundation

extension ConversationStore {
    func notifyOfSessionsWantingAttention(_ events: [SessionAttentionEvent]) {
        for event in events where !isInView(event.source) {
            guard let notification = sessionNotification(for: event) else { continue }
            sessionNotifier.notify(notification)
        }
    }

    func showTab(notifiedAbout source: SessionAttentionSource) -> Bool {
        guard let tab = runningTab(for: source) else { return false }
        selectTerminal(tab.id)
        return true
    }

    func reattach(notifiedAbout source: SessionAttentionSource) {
        guard let conversationID = source.conversationID, let conversation = conversation(withID: conversationID) else { return }
        showRunningCLI(for: conversation)
    }

    func isInView(_ source: SessionAttentionSource) -> Bool {
        guard let tabID = source.tabID else { return false }
        return sessionNotifier.isApplicationActive && terminalIDsOnScreen.contains(tabID)
    }

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
        guard let conversationID = event.source.conversationID, let conversation = conversation(withID: conversationID),
            !hiddenConversationProviders.hides(conversation.provider)
        else {
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
