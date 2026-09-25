import Foundation

/// Keeps names chosen with `/rename` inside a running Claude Code tab in step with the tab title
/// and the matching sidebar entry, without waiting for a full `refreshThisMac()`.
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
            guard let record = registry.record(forProcessID: session.cliProcessID) else { continue }
            applyLiveName(from: record, to: session)
        }
    }

    func applyLiveName(from record: ClaudeLiveSessionRecord, to session: TerminalSession) {
        guard let liveName = record.userChosenName else { return }
        // The CLI can move to another session, e.g. with `/clear`, while the tab still points at the one it was linked to.
        if let linkedConversation = session.conversation, linkedConversation.sessionID != record.sessionID { return }

        applySuggestedTitle(liveName, toSessionID: record.sessionID, provider: .claude)
        let matchingConversation = conversations.first {
            $0.provider == .claude && $0.sessionID == record.sessionID
        }
        session.updateDisplayTitle(matchingConversation.map(title(for:)) ?? liveName)
    }
}
