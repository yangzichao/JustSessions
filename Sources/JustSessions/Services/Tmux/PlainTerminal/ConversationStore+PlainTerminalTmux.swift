import Foundation

/// A plain terminal's shell runs in a tmux session of its tab's own where the host has tmux (`makePlainTerminal`). It
/// keeps running while the tab is saved to reopen, through a quit, an update, a crash, or a dropped connection, and the
/// reopened or reconnected tab attaches to it again. It ends once nothing will: when you close its tab, when you close
/// one of several windows, and when the last window closes or the app quits with Reopen tabs off. After a crash with
/// Reopen tabs off it runs on until the Mac or the host restarts.
extension ConversationStore {
    /// What ⌘F searches; nil on this Mac without a tmux the app can use.
    func plainTerminalTmuxHistory(sessionName: String, on host: SessionHost) -> TmuxHistory? {
        switch host {
        case .thisMac:
            commandResolver.thisMacTmuxServer().map { TmuxHistory.onThisMac(sessionName: sessionName, server: $0) }
        case .ssh(let destination):
            TmuxHistory.onSSHHost(destination, sessionName: sessionName)
        }
    }

    /// As its tab closes.
    func endPlainTerminalTmuxSession(of tab: TerminalSession) {
        guard tab.isPlainTerminal, let tmuxSessionName = tab.tmuxSessionName else { return }
        endTmuxSession(named: tmuxSessionName, on: tab.host)
    }

    /// As the window closes: its tabs are dropped for good when another window stays open, or when Reopen tabs is off
    /// (`OpenTabPersistence.closeWindow`). Then the shells of its plain terminals end too, and those of plain terminals
    /// still waiting to reopen in it.
    func endPlainTerminalsOfClosingWorkspace(reopensTabs: Bool = TabReopeningSettingsStore.shared.reopensTabsAtLaunch) {
        let anotherWindowStaysOpen = windowRegistry.stores.contains { $0 !== self }
        guard anotherWindowStaysOpen || !reopensTabs else { return }
        for (host, tmuxSessionName) in plainTerminalTmuxSessions() {
            endTmuxSession(named: tmuxSessionName, on: host)
        }
    }

    /// As the app quits with Reopen tabs off, before its SSH logins end: this Mac's tmux ends the shells at once, and
    /// the SSH hosts' together, waiting at most `sshTimeout` for them.
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

    /// The window's plain terminals' tmux sessions, open and still waiting to reopen.
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
