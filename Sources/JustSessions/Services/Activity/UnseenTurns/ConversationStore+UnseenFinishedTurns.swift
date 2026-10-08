import Foundation

/// Marks a session whose CLI on this Mac finished a turn while you were not looking, until you look: select its tab,
/// show it in a split, or bring the app to the front with it selected. See `UnseenFinishedTurns`.
extension ConversationStore {
    /// Follows what the CLI activity sync saw. A tab in view is seen there too, such as when the app comes to the
    /// front with it selected.
    func noteUnseenFinishedTurns(after observations: [SessionActivityObservation], events: [SessionAttentionEvent]) {
        var next = unseenFinishedTurns
        next.update(after: observations, events: events, isInView: isInView)
        if next != unseenFinishedTurns { unseenFinishedTurns = next }
    }

    /// Tabs that come on screen are seen at once, without waiting for the next activity sync.
    func markTerminalsOnScreenSeen() {
        guard !unseenFinishedTurns.isEmpty else { return }
        let onScreen = terminalIDsOnScreen
        var next = unseenFinishedTurns
        for tab in terminalSessions where onScreen.contains(tab.id) {
            next.markSeen(tab.attentionSource)
        }
        if next != unseenFinishedTurns { unseenFinishedTurns = next }
    }

    func hasUnseenFinishedTurn(_ tab: TerminalSession) -> Bool {
        unseenFinishedTurns.contains(tab.attentionSource)
    }

    /// For a session whose CLI runs in tmux on this Mac with no tab open.
    func hasUnseenFinishedTurn(detachedConversationID conversationID: String) -> Bool {
        unseenFinishedTurns.contains(.detachedTmux(conversationID: conversationID))
    }

    func isWaitingForYou(_ tab: TerminalSession) -> Bool {
        tab.isRunning && WaitingForYou.includes(activity: tab.cliActivity, hasUnseenFinishedTurn: hasUnseenFinishedTurn(tab))
    }

    /// The session's CLI waits on you, in its tab or in tmux with no tab open.
    func isWaitingForYou(_ conversation: Conversation) -> Bool {
        if let tab = runningTerminal(for: conversation) { return isWaitingForYou(tab) }
        guard isRunningInTmux(conversation) else { return false }
        return WaitingForYou.includes(
            activity: detachedCLIActivities[conversation.id],
            hasUnseenFinishedTurn: hasUnseenFinishedTurn(detachedConversationID: conversation.id)
        )
    }
}

extension TerminalSession {
    /// The tab's CLI, as the activity sync and its notifications know it.
    var attentionSource: SessionAttentionSource {
        .tab(id: id, conversationID: conversation?.id)
    }
}
