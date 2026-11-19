import Foundation

extension ConversationStore {
    func thisMacTabCommand(
        running command: NativeCLICommand,
        tmuxSessionName: String,
        historyLimit: Int? = nil
    ) -> (command: NativeCLICommand, tmuxSessionName: String?) {
        guard let tmuxServer = commandResolver.thisMacTmuxServer() else { return (command, nil) }
        return (tmuxServer.command(attachingTo: tmuxSessionName, running: command, historyLimit: historyLimit), tmuxSessionName)
    }

    func startTmuxPaneProcessLookup(interval: Duration = .seconds(1)) {
        runPeriodically(every: interval) { await $0.lookUpTmuxPaneProcesses() }
    }

    func lookUpTmuxPaneProcesses() async {
        let tabs = terminalSessions.filter {
            $0.host == .thisMac && !$0.isPlainTerminal && $0.tmuxSessionName != nil && $0.tmuxPaneProcessID == nil && !$0.hasExited
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
