import Foundation

extension ConversationStore {
    func usesTmuxPrefix(on host: SessionHost) -> Bool {
        guard let destination = host.sshDestination else { return false }
        return remoteHostsUsingTmuxPrefix.usesTmuxPrefix(destination)
    }

    func setUsesTmuxPrefix(
        _ usesTmuxPrefix: Bool,
        on host: String,
        remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()
    ) {
        guard remoteHostList.hosts.contains(host), self.usesTmuxPrefix(on: .ssh(host)) != usesTmuxPrefix else { return }
        connectIfDisconnected(.ssh(host))
        remoteHostsUsingTmuxPrefix.setUsesTmuxPrefix(usesTmuxPrefix, for: host)
        remoteHostsUsingTmuxPrefix.save(to: userDefaults)
        remakeTabsWaitingToBeShown(on: .ssh(host))
        let command = RemoteTmuxCommands.setPrefixOptionsCommand(usingHostPrefix: usesTmuxPrefix, on: host)
        tmuxCommandQueues.runAfterEarlierCommands(on: .ssh(host)) { _ = remoteRunner.run(host, command, 30) }
    }

    func remakeTabsWaitingToBeShown(on host: SessionHost) {
        for index in terminalSessions.indices {
            let tab = terminalSessions[index]
            guard tab.host == host, tab.isWaitingToBeShown, tab.tmuxSessionName != nil,
                let replacement = remadeTabWaitingToBeShown(tab)
            else { continue }
            replaceTerminal(at: index, with: replacement)
        }
    }

    private func remadeTabWaitingToBeShown(_ tab: TerminalSession) -> TerminalSession? {
        if let conversation = tab.conversation {
            return try? makeTerminal(for: conversation, action: .resume, startsOnceShown: true, engine: tab.engine)
        }
        guard tab.isPlainTerminal else { return nil }
        return try? makePlainTerminal(
            in: ProjectLocation(host: tab.host, path: tab.projectPath),
            tmuxSessionName: tab.tmuxSessionName,
            startsOnceShown: true,
            engine: tab.engine
        )
    }
}
