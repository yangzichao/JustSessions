import Foundation

extension ConversationStore {
    /// Every session whose CLI runs: in a tab of any window, or in tmux with no tab open, on this Mac or on an SSH
    /// host as of the host's last refresh. Only this window's tabs are listed by id. A CLI started outside the app
    /// is not seen, since only the tmux sessions the app named are listed.
    var sessionsRunning: SessionsRunning {
        var running = SessionsRunning()
        for tab in terminalSessions where tab.isRunning && !tab.isPlainTerminal {
            running.terminalIDs.insert(tab.id)
            if let conversationID = tab.conversation?.id { running.conversationIDs.insert(conversationID) }
        }
        running.conversationIDs.formUnion(runningTerminalsInOtherWindows.keys)
        for (host, tmuxSessionNames) in tmuxSessionNamesByHost {
            for tmuxSessionName in tmuxSessionNames {
                // A new session's temporary name names no listed session yet.
                guard let (provider, sessionID) = TmuxSessionName.session(named: tmuxSessionName) else { continue }
                running.conversationIDs.insert(Conversation.id(provider: provider, sessionID: sessionID, host: host))
            }
        }
        return running
    }
}
