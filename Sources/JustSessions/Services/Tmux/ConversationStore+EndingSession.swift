import Foundation

extension ConversationStore {
    func canEndSession(_ conversation: Conversation) -> Bool {
        runningTerminal(for: conversation) != nil
            || runningTerminalInAnotherWindow(for: conversation) != nil
            || isRunningInTmux(conversation)
    }

    func endSession(_ conversation: Conversation) {
        let host = conversation.host
        let windowStores = otherWindowStores + [self]
        var endedTmuxNames: Set<String> = []
        for store in windowStores {
            for tab in store.terminalSessions where tab.conversation?.id == conversation.id {
                if let tmuxName = tab.tmuxSessionName { endedTmuxNames.insert(tmuxName) }
                store.closeTerminal(tab.id, endingTmuxSession: true)
            }
        }
        let sessionTmuxName = TmuxSessionName.forConversation(conversation)
        if isRunningInTmux(conversation) && !endedTmuxNames.contains(sessionTmuxName) {
            endTmuxSession(named: sessionTmuxName, on: host)
            endedTmuxNames.insert(sessionTmuxName)
        }
        for store in windowStores { store.tmuxSessionNamesByHost[host]?.subtract(endedTmuxNames) }
    }

    func endSessions(_ conversations: [Conversation]) {
        for conversation in conversations where canEndSession(conversation) {
            endSession(conversation)
        }
    }

    func closeTerminalEndingSession(_ id: UUID) {
        guard let tab = terminalSessions.first(where: { $0.id == id }) else { return }
        if let conversation = tab.conversation {
            endSession(conversation)
        } else {
            closeTerminal(id, endingTmuxSession: true)
        }
    }
}
