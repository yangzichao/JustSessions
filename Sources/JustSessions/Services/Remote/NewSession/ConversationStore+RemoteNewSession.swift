import Foundation

/// New sessions and branches started in a project on a remote host. While such a tab runs, its host is copied
/// again every few seconds until the tab is linked to its session and that session has a title.
extension ConversationStore {
    func launchNewRemoteSession(provider: ConversationProvider, host: String, projectPath: String) {
        let tmuxSessionName = TmuxSessionName.unique(for: provider)
        let command = RemoteCLICommandBuilder().command(
            host: host,
            provider: provider,
            projectPath: projectPath,
            arguments: [],
            tmuxSessionName: tmuxSessionName,
            startCommand: customStartCommand(for: provider, on: .ssh(host))
        )
        let session = TerminalSession(
            conversation: nil,
            provider: provider,
            projectPath: projectPath,
            action: .new,
            displayTitle: provider.newSessionTabTitle,
            command: command,
            host: .ssh(host),
            sessionIDsKnownAtLaunch: sessionIDsKnownAtLaunch(of: provider, on: .ssh(host)),
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
