import Foundation

extension ConversationStore {
    func startClaudeLiveNameSync(interval: Duration = .seconds(1)) {
        runPeriodically(every: interval) { $0.synchronizeClaudeLiveNames() }
    }

    func synchronizeClaudeLiveNames(registry: ClaudeLiveSessionRegistry = ClaudeLiveSessionRegistry(), now: Date = .now) {
        for session in terminalSessions where session.provider == .claude {
            guard !session.hasExited else {
                if session.unlistedClaudeSession != nil { stopWaitingForUnlistedSession(of: session) }
                continue
            }
            let record =
                session.host == .thisMac
                ? registry.record(forProcessID: session.cliProcessID)
                : session.terminalTitle.flatMap(RemoteClaudeSessionTitle.record(inTerminalTitle:))
            guard let record else { continue }
            followClaudeSessionSwitch(of: session, to: record.sessionID, now: now)
            applyLiveName(from: record, to: session)
        }
    }

    func applyLiveName(from record: ClaudeLiveSessionRecord, to session: TerminalSession) {
        guard let liveName = record.userChosenName else { return }
        if let linkedConversation = session.conversation, linkedConversation.sessionID != record.sessionID {
            guard var unlisted = session.unlistedClaudeSession, unlisted.sessionID == record.sessionID else { return }
            if unlisted.chosenName != liveName {
                unlisted.chosenName = liveName
                session.unlistedClaudeSession = unlisted
            }
            if let title = titleWhileWaitingForUnlistedSession(of: session) { session.updateDisplayTitle(title) }
            return
        }
        applyChosenName(liveName, toSessionID: record.sessionID, provider: .claude, shownIn: session)
    }
}
