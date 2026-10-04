import Foundation

/// Keeps names chosen with `/rename` inside a running Claude Code tab in step with the tab title
/// and the matching sidebar entry, without waiting for a full `refreshThisMac()`. A tab whose CLI moved to another
/// session, as with `/clear`, follows it first; see `followClaudeSessionSwitch`.
extension ConversationStore {
    func startClaudeLiveNameSync(interval: Duration = .seconds(1)) {
        runPeriodically(every: interval) { $0.synchronizeClaudeLiveNames() }
    }

    func synchronizeClaudeLiveNames(registry: ClaudeLiveSessionRegistry = ClaudeLiveSessionRegistry()) {
        for session in terminalSessions where session.provider == .claude && !session.hasExited {
            guard let record = registry.record(forProcessID: session.cliProcessID) else { continue }
            followClaudeSessionSwitch(of: session, to: record.sessionID)
            applyLiveName(from: record, to: session)
        }
    }

    func applyLiveName(from record: ClaudeLiveSessionRecord, to session: TerminalSession) {
        guard let liveName = record.userChosenName else { return }
        // Until the tab follows its CLI to a session `/clear` started, which waits for a refresh to list that session,
        // the name belongs to a session the tab does not show.
        if let linkedConversation = session.conversation, linkedConversation.sessionID != record.sessionID { return }

        applySuggestedTitle(liveName, toSessionID: record.sessionID, provider: .claude)
        let matchingConversation = conversations.first {
            $0.provider == .claude && $0.sessionID == record.sessionID
        }
        session.updateDisplayTitle(matchingConversation.map(title(for:)) ?? liveName)
    }
}
