import Foundation

/// Claude Code draws in light or dark colors, and redraws when its terminal reports a theme change and then answers
/// its background query. tmux before 3.6 passes on neither: it asks the tab for its colors only when a client attaches,
/// and answers the CLI from what it learned then. tmux 3.6 and later subscribe to theme changes themselves, so only
/// an SSH host's older tmux leaves a light/dark change unheard. Its Claude Code tab then attaches its tmux client
/// again, which makes tmux ask for the new colors, and reports the change after answering; tmux passes the report on
/// to the CLI. A CLI that never asked for reports could take one as typed text, so other CLIs' tabs get none.
extension ConversationStore {
    func followLightDarkChanges(of tab: TerminalSession) {
        guard tab.provider == .claude, tab.host.sshDestination != nil else { return }
        tab.terminalView.onUnheardLightDarkChange = { [weak self, weak tab] in
            guard let self, let tab else { return }
            reattachRemoteTmuxClient(of: tab)
        }
    }

    func reattachRemoteTmuxClient(of tab: TerminalSession, remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        guard tab.provider == .claude, tab.isRunning, let destination = tab.host.sshDestination,
              let tmuxSessionName = tab.tmuxSessionName else { return }
        let terminalView = tab.terminalView
        terminalView.reportThemeAfterNextBackgroundQuery()
        let command = RemoteTmuxCommands.reattachClientsCommand(tmuxSessionName)
        // After the host's other tmux commands, such as the rename that gave the session this name.
        tmuxCommandQueues.run(on: tab.host) {
            guard remoteRunner.run(destination, command, 30)?.exitStatus != 0 else { return }
            // Without tmux, or without the session, no client attaches again to ask for the colors.
            Task { @MainActor in terminalView.cancelThemeReportAfterNextBackgroundQuery() }
        }
    }
}
