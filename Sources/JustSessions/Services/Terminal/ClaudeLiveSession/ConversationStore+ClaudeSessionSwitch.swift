import Foundation

/// Claude Code's `/clear`, its `/resume` of another session, and its `/branch`, which writes a copy of the conversation
/// as a new session, move a running CLI to another session. The live registry says which session the tab's CLI is in
/// now, so the tab follows it there: from then on its title, its row in the sidebar, and the tmux session that Resume
/// reattaches to all belong to that session. `/clear` keeps a name chosen with `/rename`, and Claude Code writes it
/// into the new session too, so the name comes along.
extension ConversationStore {
    /// Whether the tab is linked to `sessionID` afterwards. Until a refresh lists that session, the tab waits on it
    /// (`TerminalSession.unlistedClaudeSession`) and asks its host for refreshes; see `askToList(_:for:linkedTo:now:)`.
    @discardableResult
    func followClaudeSessionSwitch(of session: TerminalSession, to sessionID: String, now: Date = .now) -> Bool {
        // A new session's tab is linked by new session discovery instead.
        guard let linkedConversation = session.conversation else { return false }
        guard linkedConversation.sessionID != sessionID else {
            // The CLI went back, as with `/resume` of the session the tab is linked to.
            if session.unlistedClaudeSession != nil { stopWaitingForUnlistedSession(of: session) }
            return true
        }
        guard
            let switchedConversation = conversations.first(where: {
                $0.provider == .claude && $0.host == session.host && $0.sessionID == sessionID
            })
        else {
            // The CLI moved on again before a refresh listed the session it was in; that one's name goes too.
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

    /// The tab's title while it waits on a session no refresh has listed: the name given in the app to that session,
    /// which wins as once it is listed (LIV-01), or else the name the CLI gave it. Nil while the tab waits on none, or
    /// neither named it, and the tab shows the session it is linked to.
    func titleWhileWaitingForUnlistedSession(of session: TerminalSession) -> String? {
        guard let unlisted = session.unlistedClaudeSession else { return nil }
        let conversationID = Conversation.id(provider: .claude, sessionID: unlisted.sessionID, host: session.host)
        return titleAliases.customTitlesByConversationID[conversationID] ?? unlisted.chosenName
    }

    /// The session a tab's Rename renames, which its dialog opens on: the one the tab shows (LIV-08). While the tab
    /// waits for a refresh to list the session its CLI moved to, that one, so the name is kept for it, shows on the tab
    /// at once, and names its row once listed, rather than renaming the row of the session the tab is still linked to.
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

    /// Asks for a refresh of the tab's host that starts after the move, so it can list the session, and again until
    /// one does (LIV-07): never while a refresh that may have read the host before the move runs, since an SSH host's
    /// refresh drops a request then, and on this Mac a request joins any window's scan in flight. After the first
    /// request, this Mac asks again once the session's transcript beside the linked session's has changed since, as new
    /// session discovery does, and no sooner than a new session's tab refreshes it. An SSH host, whose files the app
    /// can't see, is copied once more only once every window's copies of it end, as often as for a new session's tab
    /// (SSH-66) counted from the end of the last, and, after one that didn't fail, only once the relay's title has
    /// changed since the tab last asked: an idle tab after `/clear` writes nothing. After a few failures in a row it
    /// waits as the auto refresh does. A host removed, disconnected (SSH-101), or waiting for Connect… in any window
    /// isn't asked; connecting refreshes it. Nor is one `SSHHostReachability` remembers out of reach, whose copy would
    /// fail at once without connecting, so the tab's own copies count as failures only when they tried the host;
    /// copies other tabs or the auto refresh start meanwhile still count. Each move starts over: the first request for a
    /// new session goes as soon as nothing that may have read the host before the move runs.
    private func askToList(
        _ unlisted: inout UnlistedClaudeSession,
        for session: TerminalSession,
        linkedTo linkedConversation: Conversation,
        now: Date
    ) {
        switch session.host {
        case .thisMac:
            guard !isThisMacScanUnderWay else { return }
            if let requestedAt = unlisted.refreshRequestedAt {
                guard now.timeIntervalSince(requestedAt) >= Self.refreshIntervalWhileWaitingForAppearingSession
                else { return }
                let transcript = linkedConversation.sourceFile.deletingLastPathComponent()
                    .appendingPathComponent("\(unlisted.sessionID).jsonl")
                guard ConversationMetadata.fileModificationDate(transcript) > requestedAt else { return }
            }
            unlisted.refreshRequestedAt = now
            refreshThisMac()
        case .ssh(let destination):
            let windows = [self] + otherWindowStores
            guard remoteHostList.hosts.contains(destination), !isDisconnected(destination),
                !windows.contains(where: { $0.sshHostsNeedingLogIn.contains(destination) }),
                SSHHostReachability.shared.recentFailureOutput(on: destination) == nil,
                !windows.contains(where: { $0.hostRefreshStatuses[session.host] == .refreshing })
            else { return }
            let copies = RemoteHostCopies.combined(windows.map { $0.remoteHostCopies.copies(of: destination) })
            // A copy that started after the move ended without listing the session.
            if let startedAt = copies.lastStartedAt, startedAt >= unlisted.movedAt, let endedAt = copies.lastEndedAt {
                guard now.timeIntervalSince(endedAt) >= Self.waitBeforeCopyingAgainForUnlistedSession(after: copies)
                else { return }
                if copies.failuresInARow == 0, session.terminalTitle == unlisted.terminalTitleAtRequest { return }
            }
            unlisted.refreshRequestedAt = now
            unlisted.terminalTitleAtRequest = session.terminalTitle
            refreshRemoteHost(destination)
        }
    }

    /// How many failed copies in a row a waiting tab tries again after 10 seconds before it waits as the auto refresh
    /// does after so many failures.
    static let failedCopiesBeforeWaitingLonger = 3

    static func waitBeforeCopyingAgainForUnlistedSession(after copies: RemoteHostCopies.Copies) -> TimeInterval {
        guard copies.failuresInARow >= failedCopiesBeforeWaitingLonger else {
            return refreshIntervalWhileWaitingForRemoteSession
        }
        return HostAutoRefreshSchedule.wait(afterFailuresInARow: copies.failuresInARow - failedCopiesBeforeWaitingLonger + 1)
    }

    /// The tab shows the session it is linked to again.
    func stopWaitingForUnlistedSession(of session: TerminalSession) {
        session.unlistedClaudeSession = nil
        guard let linkedConversation = session.conversation,
            let current = conversationIndex.conversation(withID: linkedConversation.id)
        else { return }
        session.updateDisplayTitle(title(for: current))
    }
}
