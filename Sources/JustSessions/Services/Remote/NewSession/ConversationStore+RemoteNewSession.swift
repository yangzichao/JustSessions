import Foundation

extension ConversationStore {
    func launchNewRemoteSession(
        provider: ConversationProvider,
        host: String,
        projectPath: String,
        initialPrompt: String? = nil,
        runsInTmux: Bool = true,
        deletesSessionWhenClosed: Bool = false
    ) {
        connectIfDisconnected(.ssh(host))
        let startCommand = customStartCommand(for: provider, on: .ssh(host))
        let preassignedSessionID =
            provider == .claude
            ? remoteClaudeSessionIDFlagSupport.preassignedSessionID(host: host, startCommand: startCommand)
            : nil
        let tmuxSessionName =
            runsInTmux
            ? preassignedSessionID.map { TmuxSessionName.forSession(provider: provider, sessionID: $0) }
                ?? TmuxSessionName.unique(for: provider)
            : nil
        let command = RemoteCLICommandBuilder().command(
            host: host,
            provider: provider,
            projectPath: projectPath,
            arguments: (preassignedSessionID.map { [ClaudeSessionIDFlagSupport.flag, $0] } ?? [])
                + (initialPrompt.map(provider.initialPromptArguments) ?? []),
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
        session.deletesSessionWhenClosed = deletesSessionWhenClosed
        session.onProcessFinished = { [weak self] in self?.refreshRemoteHost(host) }
        openTerminal(session)
    }

    static let refreshIntervalWhileWaitingForRemoteSession: TimeInterval = 10

    func startRemoteNewSessionPolling(interval: Duration = .seconds(refreshIntervalWhileWaitingForRemoteSession)) {
        runPeriodically(every: interval) { store in
            for host in store.hostsWithRemoteNewSessionsToFollow() { store.refreshRemoteHost(host) }
        }
    }

    private func hostsWithRemoteNewSessionsToFollow() -> Set<String> {
        Set(
            terminalSessions.compactMap { session -> String? in
                guard let host = session.host.sshDestination, session.startsNewSession, !session.hasExited else { return nil }
                let needsTitle = session.conversation?.suggestedTitle == ConversationMetadata.untitledConversationTitle
                return session.isNewSessionAwaitingConversation || needsTitle ? host : nil
            })
    }
}
