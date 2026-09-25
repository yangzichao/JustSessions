import Foundation

/// With tmux installed, this Mac's tabs run their CLI in JustSessions' own tmux server; see `ThisMacTmuxServer`.
extension ConversationStore {
    /// The command a tab on this Mac runs: `command` in the tmux session `tmuxSessionName` when tmux is installed,
    /// or `command` alone. Also returns the tmux session's name when there is one.
    func thisMacTabCommand(
        running command: NativeCLICommand,
        tmuxSessionName: String
    ) -> (command: NativeCLICommand, tmuxSessionName: String?) {
        guard let tmuxServer = commandResolver.thisMacTmuxServer() else { return (command, nil) }
        return (tmuxServer.command(attachingTo: tmuxSessionName, running: command), tmuxSessionName)
    }

    func startTmuxPaneProcessLookup(interval: Duration = .seconds(1)) {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self else { return }
                await self.lookUpTmuxPaneProcesses()
            }
        }
    }

    /// A tab whose CLI runs in tmux on this Mac runs a tmux client; the CLI is a process of the tmux server. This
    /// finds it for tabs that do not know it yet, for the lookups that go by the CLI's process.
    func lookUpTmuxPaneProcesses() async {
        let tabs = terminalSessions.filter {
            $0.host == .thisMac && $0.tmuxSessionName != nil && $0.tmuxPaneProcessID == nil && !$0.hasExited
        }
        guard !tabs.isEmpty, let tmuxServer = commandResolver.thisMacTmuxServer() else { return }
        let processIDs = await Task.detached(priority: .utility) {
            tmuxServer.paneProcessIDsBySessionName()
        }.value
        for tab in tabs {
            guard let tmuxSessionName = tab.tmuxSessionName, let processID = processIDs[tmuxSessionName] else { continue }
            tab.tmuxPaneProcessID = processID
        }
    }
}
