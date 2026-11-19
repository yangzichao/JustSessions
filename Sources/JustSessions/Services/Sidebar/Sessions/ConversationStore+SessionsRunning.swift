import Foundation

extension ConversationStore {
    var sessionsRunning: SessionsRunning {
        var running = SessionsRunning()
        for tab in terminalSessions where tab.isRunning && !tab.isPlainTerminal {
            running.terminalIDs.insert(tab.id)
            if let conversationID = tab.conversation?.id { running.conversationIDs.insert(conversationID) }
        }
        running.conversationIDs.formUnion(runningTerminalsInOtherWindows.keys)
        for (host, tmuxSessionNames) in tmuxSessionNamesByHost {
            for tmuxSessionName in tmuxSessionNames {
                guard let (provider, sessionID) = TmuxSessionName.session(named: tmuxSessionName) else { continue }
                running.conversationIDs.insert(Conversation.id(provider: provider, sessionID: sessionID, host: host))
            }
        }
        return running
    }
}
