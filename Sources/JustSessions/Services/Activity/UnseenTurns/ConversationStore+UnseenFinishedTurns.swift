import Foundation

/// Marks a session whose CLI on this Mac finished a turn while you were not looking, until you look: select its tab,
/// show it in a split, or bring the app to the front with it selected. See `UnseenFinishedTurns`. Each tab carries its
/// own mark for the views that show it, set from the store's.
extension ConversationStore {
    /// Follows what the CLI activity sync saw. A tab in view is seen there too, such as when the app comes to the
    /// front with it selected.
    func noteUnseenFinishedTurns(after observations: [SessionActivityObservation], events: [SessionAttentionEvent]) {
        var next = unseenFinishedTurns
        next.update(after: observations, events: events, isInView: isInView)
        applyUnseenFinishedTurns(next)
    }

    /// Tabs that come on screen are seen at once, without waiting for the next activity sync.
    func markTerminalsOnScreenSeen() {
        guard !unseenFinishedTurns.isEmpty else { return }
        let onScreen = terminalIDsOnScreen
        var next = unseenFinishedTurns
        for tab in terminalSessions where onScreen.contains(tab.id) {
            next.markSeen(tab.attentionSource)
        }
        applyUnseenFinishedTurns(next)
    }

    /// For a session whose CLI runs in tmux on this Mac with no tab open.
    func hasUnseenFinishedTurn(detachedConversationID conversationID: String) -> Bool {
        unseenFinishedTurns.contains(.detachedTmux(conversationID: conversationID))
    }

    /// What a session's row shows for its CLI running in tmux with no tab open.
    func detachedCLIStatus(of conversation: Conversation) -> SessionRunStatus {
        SessionRunStatus.running(detachedCLIActivities[conversation.id])
            .markingUnseenFinishedTurn(hasUnseenFinishedTurn(detachedConversationID: conversation.id))
    }

    /// Every session whose CLI waits on you, in a tab of any window or in tmux with no tab open. Only this window's
    /// tabs are listed by id.
    var sessionsWaitingForYou: SessionsWaitingForYou {
        var waiting = SessionsWaitingForYou()
        for tab in terminalSessions where tab.isWaitingForYou {
            waiting.terminalIDs.insert(tab.id)
            if let conversationID = tab.conversation?.id { waiting.conversationIDs.insert(conversationID) }
        }
        for (conversationID, tab) in runningTerminalsInOtherWindows where tab.isWaitingForYou {
            waiting.conversationIDs.insert(conversationID)
        }
        for (conversationID, activity) in detachedCLIActivities where WaitingForYou.includes(
            activity: activity,
            hasUnseenFinishedTurn: hasUnseenFinishedTurn(detachedConversationID: conversationID)
        ) {
            waiting.conversationIDs.insert(conversationID)
        }
        return waiting
    }

    private func applyUnseenFinishedTurns(_ next: UnseenFinishedTurns) {
        guard next != unseenFinishedTurns else { return }
        unseenFinishedTurns = next
        for tab in terminalSessions {
            tab.updateHasUnseenFinishedTurn(next.contains(tab.attentionSource))
        }
        // Other windows' Waiting for you filter counts these tabs' sessions too.
        windowRegistry.tabsChanged(in: self)
    }
}

extension TerminalSession {
    /// The tab's CLI, as the activity sync and its notifications know it.
    var attentionSource: SessionAttentionSource {
        .tab(id: id, conversationID: conversation?.id)
    }
}
