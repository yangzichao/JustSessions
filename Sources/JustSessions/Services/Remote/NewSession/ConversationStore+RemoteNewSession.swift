import Foundation

/// New sessions and branches started in a project on a remote host. While such a tab runs, its host is copied
/// again every few seconds until the tab is linked to its session and that session has a title.
extension ConversationStore {
    /// A new Claude Code session starts with an id of its own when the host's CLI takes one, and its tmux session
    /// has that session's name from the start; see `RemoteClaudeSessionIDFlagSupport`.
    func launchNewRemoteSession(provider: ConversationProvider, host: String, projectPath: String) {
        let startCommand = customStartCommand(for: provider, on: .ssh(host))
        let preassignedSessionID = provider == .claude
            ? remoteClaudeSessionIDFlagSupport.preassignedSessionID(host: host, startCommand: startCommand)
            : nil
        let tmuxSessionName = preassignedSessionID.map { TmuxSessionName.forSession(provider: provider, sessionID: $0) }
            ?? TmuxSessionName.unique(for: provider)
        let command = RemoteCLICommandBuilder().command(
            host: host,
            provider: provider,
            projectPath: projectPath,
            arguments: preassignedSessionID.map { [ClaudeSessionIDFlagSupport.flag, $0] } ?? [],
            tmuxSessionName: tmuxSessionName,
            usesHostTmuxPrefix: usesTmuxPrefix(on: .ssh(host)),
            startCommand: startCommand
        )
        let session = TerminalSession(
            engine: terminalEngineStore.engine,
            conversation: nil,
            provider: provider,
            projectPath: projectPath,
            action: .new,
            displayTitle: provider.newSessionTabTitle,
            command: command,
            preassignedSessionID: preassignedSessionID,
            host: .ssh(host),
            sessionIDsKnownAtLaunch: preassignedSessionID == nil ? sessionIDsKnownAtLaunch(of: provider, on: .ssh(host)) : [],
            tmuxSessionName: tmuxSessionName
        )
        session.onProcessFinished = { [weak self] in self?.refreshRemoteHost(host) }
        openTerminal(session)
    }

    func startRemoteNewSessionPolling(interval: Duration = .seconds(10)) {
        runPeriodically(every: interval) { store in
            for host in store.hostsWithRemoteNewSessionsToFollow() { store.refreshRemoteHost(host) }
        }
    }

    private func hostsWithRemoteNewSessionsToFollow() -> Set<String> {
        Set(terminalSessions.compactMap { session -> String? in
            guard let host = session.host.sshDestination, session.startsNewSession, !session.hasExited else { return nil }
            let needsTitle = session.conversation?.suggestedTitle == ConversationMetadata.untitledConversationTitle
            return session.isNewSessionAwaitingConversation || needsTitle ? host : nil
        })
    }
}
