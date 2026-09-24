import Foundation

/// Keeps names chosen with `/rename` inside a running Claude Code tab in step with the tab title
/// and the matching sidebar entry, without waiting for a full `refresh()`.
extension ConversationStore {
    func startClaudeLiveNameSync(interval: Duration = .seconds(1)) {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self else { return }
                self.synchronizeClaudeLiveNames()
            }
        }
    }

    func synchronizeClaudeLiveNames(registry: ClaudeLiveSessionRegistry = ClaudeLiveSessionRegistry()) {
        for session in terminalSessions where session.provider == .claude && !session.hasExited {
            guard let record = registry.record(forProcessID: session.processID) else { continue }
            applyLiveName(from: record, to: session)
        }
    }

    func applyLiveName(from record: ClaudeLiveSessionRecord, to session: TerminalSession) {
        guard let liveName = record.userChosenName else { return }
        // A branch tab runs a new session id while still pointing at the conversation it forked from.
        if let linkedConversation = session.conversation, linkedConversation.sessionID != record.sessionID { return }

        applySuggestedTitle(liveName, toSessionID: record.sessionID, provider: .claude)
        let matchingConversation = conversations.first {
            $0.provider == .claude && $0.sessionID == record.sessionID
        }
        session.updateDisplayTitle(matchingConversation.map(title(for:)) ?? liveName)
    }
}
