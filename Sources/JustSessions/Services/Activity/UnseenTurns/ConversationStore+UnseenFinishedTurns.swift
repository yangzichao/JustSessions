import Foundation

extension ConversationStore {
    func noteUnseenFinishedTurns(after observations: [SessionActivityObservation], events: [SessionAttentionEvent]) {
        var next = unseenFinishedTurns
        next.update(after: observations, events: events, isInView: isInView)
        applyUnseenFinishedTurns(next)
    }

    func markTerminalsOnScreenSeen() {
        guard !unseenFinishedTurns.isEmpty else { return }
        let onScreen = terminalIDsOnScreen
        var next = unseenFinishedTurns
        for tab in terminalSessions where onScreen.contains(tab.id) {
            next.markSeen(tab.attentionSource)
        }
        applyUnseenFinishedTurns(next)
    }

    func hasUnseenFinishedTurn(detachedConversationID conversationID: String) -> Bool {
        unseenFinishedTurns.contains(.detachedTmux(conversationID: conversationID))
    }

    func detachedCLIStatus(of conversation: Conversation) -> SessionRunStatus {
        SessionRunStatus.running(detachedCLIActivities[conversation.id])
            .markingUnseenFinishedTurn(hasUnseenFinishedTurn(detachedConversationID: conversation.id))
    }

    var sessionsWaitingForYou: SessionsWaitingForYou {
        var waiting = SessionsWaitingForYou()
        for tab in terminalSessions where tab.isWaitingForYou {
            waiting.terminalIDs.insert(tab.id)
            if let conversationID = tab.conversation?.id { waiting.conversationIDs.insert(conversationID) }
        }
        for (conversationID, tab) in runningTerminalsInOtherWindows where tab.isWaitingForYou {
            waiting.conversationIDs.insert(conversationID)
        }
        for (conversationID, activity) in detachedCLIActivities
        where WaitingForYou.includes(
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
        windowRegistry.tabsChanged(in: self)
    }
}

extension TerminalSession {
    var attentionSource: SessionAttentionSource {
        .tab(id: id, conversationID: conversation?.id)
    }
}
