import Foundation

/// Claude Code's `/clear`, its `/resume` of another session, and its `/branch`, which writes a copy of the conversation
/// as a new session, move a running CLI to another session. The live registry says which session the tab's CLI is in
/// now, so the tab follows it there: from then on its title, its row in the sidebar, and the tmux session that Resume
/// reattaches to all belong to that session. `/clear` keeps a name chosen with `/rename`, and Claude Code writes it
/// into the new session too, so the name comes along.
extension ConversationStore {
    @discardableResult
    func followClaudeSessionSwitch(of session: TerminalSession, to sessionID: String, now: Date = .now) -> Bool {
        guard let linkedConversation = session.conversation else { return false }
        guard linkedConversation.sessionID != sessionID else {
            if session.unlistedClaudeSession != nil { stopWaitingForUnlistedSession(of: session) }
            return true
        }
        guard
            let switchedConversation = conversations.first(where: {
                $0.provider == .claude && $0.host == session.host && $0.sessionID == sessionID
            })
        else {
            if let waitedOn = session.unlistedClaudeSession, waitedOn.sessionID != sessionID {
                stopWaitingForUnlistedSession(of: session)
            }
            var unlisted = session.unlistedClaudeSession ?? UnlistedClaudeSession(sessionID: sessionID, movedAt: now)
            askToList(&unlisted, for: session, linkedTo: linkedConversation, now: now)
            if session.unlistedClaudeSession != unlisted { session.unlistedClaudeSession = unlisted }
            return false
        }
        session.unlistedClaudeSession = nil
        link(session, to: switchedConversation)
        return true
    }

    func titleWhileWaitingForUnlistedSession(of session: TerminalSession) -> String? {
        guard let unlisted = session.unlistedClaudeSession else { return nil }
        let conversationID = Conversation.id(provider: .claude, sessionID: unlisted.sessionID, host: session.host)
        return titleAliases.customTitlesByConversationID[conversationID] ?? unlisted.chosenName
    }

    func conversationToRename(fromTab session: TerminalSession) -> Conversation? {
        guard let linkedConversation = session.conversation else { return nil }
        guard let unlisted = session.unlistedClaudeSession else { return linkedConversation }
        let shownTitle =
            unlisted.chosenName
            ?? conversationIndex.conversation(withID: linkedConversation.id).map(title(for:))
            ?? title(for: linkedConversation)
        return Conversation(
            provider: .claude,
            sessionID: unlisted.sessionID,
            projectPath: linkedConversation.projectPath,
            suggestedTitle: shownTitle,
            updatedAt: linkedConversation.updatedAt,
            sourceFile: linkedConversation.sourceFile.deletingLastPathComponent()
                .appendingPathComponent("\(unlisted.sessionID).jsonl"),
            host: session.host
        )
    }

    private func askToList(
        _ unlisted: inout UnlistedClaudeSession,
        for session: TerminalSession,
        linkedTo linkedConversation: Conversation,
        now: Date
    ) {
        switch session.host {
        case .thisMac:
            guard !isThisMacScanUnderWay else { return }
            let transcript = linkedConversation.sourceFile.deletingLastPathComponent()
                .appendingPathComponent("\(unlisted.sessionID).jsonl")
            guard
                UnlistedClaudeSessionRefreshPolicy.shouldRefreshThisMac(
                    for: unlisted,
                    transcriptModificationDate: { ConversationMetadata.fileModificationDate(transcript) },
                    now: now
                )
            else { return }
            unlisted.refreshRequestedAt = now
            refreshThisMac()
        case .ssh(let destination):
            let windows = [self] + otherWindowStores
            guard canAskForUnlistedSessionCopy(of: destination, among: windows) else { return }
            let copies = RemoteHostCopies.combined(windows.map { $0.remoteHostCopies.copies(of: destination) })
            guard
                UnlistedClaudeSessionRefreshPolicy.shouldCopyRemoteHost(
                    for: unlisted,
                    copies: copies,
                    terminalTitle: session.terminalTitle,
                    now: now
                )
            else { return }
            unlisted.refreshRequestedAt = now
            unlisted.terminalTitleAtRequest = session.terminalTitle
            refreshRemoteHost(destination)
        }
    }

    private func canAskForUnlistedSessionCopy(of destination: String, among windows: [ConversationStore]) -> Bool {
        remoteHostList.hosts.contains(destination) && !isDisconnected(destination)
            && !windows.contains(where: { $0.sshHostsNeedingLogIn.contains(destination) })
            && SSHHostReachability.shared.recentFailureOutput(on: destination) == nil
            && !windows.contains(where: { $0.hostRefreshStatuses[.ssh(destination)] == .refreshing })
    }

    func stopWaitingForUnlistedSession(of session: TerminalSession) {
        session.unlistedClaudeSession = nil
        guard let linkedConversation = session.conversation,
            let current = conversationIndex.conversation(withID: linkedConversation.id)
        else { return }
        session.updateDisplayTitle(title(for: current))
    }
}
