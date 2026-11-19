import Foundation

/// Keeps names chosen with `/rename` inside a running Claude Code tab in step with the tab title
/// and the matching sidebar entry, without waiting for a full refresh. On this Mac it reads the registry; on an SSH
/// host the relay carries it in the tab's title (`RemoteClaudeSessionTitle`). A tab whose CLI moved to another
/// session, as with `/clear` or `/branch`, follows it first; see `followClaudeSessionSwitch`. Where the registry leaves
/// the name out, the transcript still has it; see `followAppendedSessionNames` on this Mac and the relay on SSH hosts.
extension ConversationStore {
    func startClaudeLiveNameSync(interval: Duration = .seconds(1)) {
        runPeriodically(every: interval) { $0.synchronizeClaudeLiveNames() }
    }

    func synchronizeClaudeLiveNames(registry: ClaudeLiveSessionRegistry = ClaudeLiveSessionRegistry(), now: Date = .now) {
        for session in terminalSessions where session.provider == .claude {
            guard !session.hasExited else {
                // An ended CLI is followed nowhere, so the tab names the session it is linked to, which Resume reopens.
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
        // Until the tab follows its CLI to the session it moved to, which waits for a refresh to list that session, the
        // name shows on the tab alone: the row of the session the tab is still linked to keeps its own (LIV-01).
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
