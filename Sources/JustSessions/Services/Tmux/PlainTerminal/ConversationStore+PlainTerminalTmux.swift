import Foundation

extension ConversationStore {
    func plainTerminalTmuxHistory(sessionName: String, on host: SessionHost) -> TmuxHistory? {
        switch host {
        case .thisMac:
            commandResolver.thisMacTmuxServer().map { TmuxHistory.onThisMac(sessionName: sessionName, server: $0) }
        case .ssh(let destination):
            TmuxHistory.onSSHHost(destination, sessionName: sessionName)
        }
    }

    func endPlainTerminalTmuxSession(of tab: TerminalSession) {
        guard tab.isPlainTerminal, let tmuxSessionName = tab.tmuxSessionName else { return }
        endTmuxSession(named: tmuxSessionName, on: tab.host)
    }

    func endPlainTerminalsOfClosingWorkspace(reopensTabs: Bool = TabReopeningSettingsStore.shared.reopensTabsAtLaunch) {
        let anotherWindowStaysOpen = windowRegistry.stores.contains { $0 !== self }
        guard anotherWindowStaysOpen || !reopensTabs else { return }
        for (host, tmuxSessionName) in plainTerminalTmuxSessions() {
            endTmuxSession(named: tmuxSessionName, on: host)
        }
    }

    func endPlainTerminalsBeforeQuitting(
        sshTimeout: TimeInterval = 3,
        remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()
    ) {
        let thisMacTmuxServer = commandResolver.thisMacTmuxServer()
        let hostsAnswered = DispatchGroup()
        for (host, tmuxSessionName) in plainTerminalTmuxSessions() {
            tmuxSessionNamesByHost[host]?.remove(tmuxSessionName)
            switch host {
            case .thisMac:
                thisMacTmuxServer?.killSession(named: tmuxSessionName)
            case .ssh(let destination):
                DispatchQueue.global(qos: .userInitiated).async(group: hostsAnswered) {
                    _ = remoteRunner.run(destination, RemoteTmuxCommands.killSessionCommand(tmuxSessionName, on: destination), sshTimeout)
                }
            }
        }
        _ = hostsAnswered.wait(timeout: .now() + sshTimeout)
    }

    private func plainTerminalTmuxSessions() -> [(host: SessionHost, tmuxSessionName: String)] {
        let openTabs = terminalSessions.compactMap { tab in
            tab.isPlainTerminal ? tab.tmuxSessionName.map { (tab.host, $0) } : nil
        }
        let waitingTabs = pendingTabReopening.waitingTabs.compactMap { waitingTab in
            waitingTab.tab.isPlainTerminal ? waitingTab.tab.tmuxSessionName.map { (waitingTab.tab.host, $0) } : nil
        }
        return openTabs + waitingTabs
    }
}
