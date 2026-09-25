import Foundation

/// New sessions started in a project on a remote host. While such a tab runs, its host is copied again every
/// few seconds until the tab is linked to its session and that session has a title.
extension ConversationStore {
    func launchNewRemoteSession(provider: ConversationProvider, host: String, projectPath: String) {
        guard provider.supportsRemoteHosts else { return }
        let command = RemoteCLICommandBuilder().command(
            host: host,
            provider: provider,
            projectPath: projectPath,
            arguments: []
        )
        let session = TerminalSession(
            conversation: nil,
            provider: provider,
            projectPath: projectPath,
            action: .new,
            displayTitle: "New \(provider.rawValue) session",
            command: command,
            remoteHost: host,
            sessionIDsKnownAtLaunch: Set(conversations.filter { $0.remoteHost == host }.map(\.sessionID))
        )
        session.onProcessFinished = { [weak self] in self?.refreshRemoteHost(host) }
        openTerminal(session)
    }

    func startRemoteNewSessionPolling(interval: Duration = .seconds(10)) {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self else { return }
                for host in self.hostsWithRemoteNewSessionsToFollow() { self.refreshRemoteHost(host) }
            }
        }
    }

    /// Links waiting new-session tabs on the host to sessions that appeared since they started.
    func linkWaitingRemoteNewSessionTabs(onHost host: String) {
        let waitingSessions = terminalSessions.filter { $0.remoteHost == host && $0.isNewSessionAwaitingConversation }
        guard !waitingSessions.isEmpty else { return }
        let matches = RemoteNewSessionMatcher.matches(
            for: waitingSessions.map(\.waitingRemoteNewSessionTab),
            in: conversations,
            alreadyLinkedConversationIDs: Set(terminalSessions.compactMap { $0.conversation?.id })
        )
        guard !matches.isEmpty else { return }
        for session in waitingSessions {
            guard let conversation = matches[session.id] else { continue }
            session.synchronize(conversation: conversation, displayTitle: title(for: conversation))
        }
        // Sidebar rows look up open terminals through the store, which does not see a tab's own changes.
        objectWillChange.send()
    }

    private func hostsWithRemoteNewSessionsToFollow() -> Set<String> {
        Set(terminalSessions.compactMap { session -> String? in
            guard let host = session.remoteHost, session.action == .new, !session.hasExited else { return nil }
            let needsTitle = session.conversation?.suggestedTitle == ConversationMetadata.untitledConversationTitle
            return session.isNewSessionAwaitingConversation || needsTitle ? host : nil
        })
    }
}

extension TerminalSession {
    var waitingRemoteNewSessionTab: WaitingRemoteNewSessionTab {
        WaitingRemoteNewSessionTab(
            terminalID: id,
            host: remoteHost ?? "",
            provider: provider,
            projectPath: projectPath,
            launchedAt: launchedAt,
            sessionIDsKnownAtLaunch: sessionIDsKnownAtLaunch
        )
    }
}
