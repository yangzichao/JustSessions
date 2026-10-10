import Foundation

/// Moves a session's tab here from the other window that has it. That tab closes and leaves its CLI running in tmux,
/// and a tab here reattaches to it, the way resuming does after a tab closes. A CLI that does not run in tmux would end
/// with that tab, so its tab stays where it is.
extension ConversationStore {
    /// Whether the session's tab in another window can move here: it has not started its CLI yet, or its CLI runs in
    /// the tmux session named after the session, which resuming here attaches to.
    func canMoveTerminalHere(for conversation: Conversation) -> Bool {
        guard runningTerminal(for: conversation) == nil, canLaunch(conversation, action: .resume),
              let (_, tab) = otherWindowRunningTerminal(for: conversation) else { return false }
        return tab.isWaitingToBeShown
            || (tab.canKeepCLIRunningAfterClose && tab.tmuxSessionName == TmuxSessionName.forConversation(conversation))
    }

    /// Over SSH, the host first confirms that its tmux runs the CLI: an SSH tab names a tmux session even on a host
    /// without tmux, where its CLI runs directly.
    func moveTerminalHere(for conversation: Conversation, remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        guard canMoveTerminalHere(for: conversation),
              let (otherStore, tab) = otherWindowRunningTerminal(for: conversation) else { return }
        guard !tab.isWaitingToBeShown, let destination = tab.host.sshDestination,
              let tmuxSessionName = tab.tmuxSessionName else {
            finishMovingTerminal(tab, from: otherStore, for: conversation)
            return
        }
        // After that window's own tmux commands for the host, such as the rename that gave the session this name.
        otherStore.tmuxCommandQueues.run(on: tab.host) { [weak self] in
            let runsInTmux = remoteRunner.run(destination, RemoteTmuxCommands.hasSessionCommand(tmuxSessionName, on: destination), 30)?.exitStatus == 0
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard runsInTmux else {
                    self.showError(
                        "The tab stays in the other window. JustSessions couldn't confirm that tmux on \(tab.host.nameInSentence) runs its CLI, and without tmux, closing the tab would end the CLI."
                    )
                    return
                }
                self.finishMovingTerminal(tab, from: otherStore, for: conversation)
            }
        }
    }

    /// The tab may have closed or ended in its window while the host answered. Resuming here then reattaches to the
    /// CLI or starts it, as it does for any session. The tab here is drawn by the engine the moved tab had, as a
    /// reconnected SSH tab is, since it is the same tab in another window.
    private func finishMovingTerminal(_ tab: TerminalSession, from otherStore: ConversationStore, for conversation: Conversation) {
        if !tab.hasExited, otherStore.terminalSessions.contains(where: { $0.id == tab.id }) {
            otherStore.closeTerminal(tab.id, endingTmuxSession: false)
        }
        launch(conversation, action: .resume, engine: tab.engine)
    }
}
