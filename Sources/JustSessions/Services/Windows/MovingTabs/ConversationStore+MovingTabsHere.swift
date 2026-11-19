import Foundation

extension ConversationStore {
    func canMoveTerminalHere(for conversation: Conversation) -> Bool {
        guard isCurrentHostLifecycle(hostLifecycleGeneration(on: conversation.host), on: conversation.host),
            runningTerminal(for: conversation) == nil, canLaunch(conversation, action: .resume),
            let (_, tab) = otherWindowRunningTerminal(for: conversation)
        else { return false }
        return tab.isWaitingToBeShown
            || (tab.canKeepCLIRunningAfterClose && tab.tmuxSessionName == TmuxSessionName.forConversation(conversation))
    }

    func moveTerminalHere(for conversation: Conversation, remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        guard canMoveTerminalHere(for: conversation),
            let (otherStore, tab) = otherWindowRunningTerminal(for: conversation)
        else { return }
        guard !tab.isWaitingToBeShown, let destination = tab.host.sshDestination,
            let tmuxSessionName = tab.tmuxSessionName
        else {
            finishMovingTerminal(tab, from: otherStore, for: conversation)
            return
        }
        let destinationLifecycle = hostLifecycleGeneration(on: conversation.host)
        let sourceLifecycle = otherStore.hostLifecycleGeneration(on: conversation.host)
        otherStore.tmuxCommandQueues.run(on: tab.host) { [weak self, weak otherStore] in
            let runsInTmux =
                remoteRunner.run(destination, RemoteTmuxCommands.hasSessionCommand(tmuxSessionName, on: destination), 30)?.exitStatus == 0
            Task { @MainActor [weak self, weak otherStore] in
                guard let self, let otherStore,
                    self.isCurrentHostLifecycle(destinationLifecycle, on: conversation.host),
                    otherStore.isCurrentHostLifecycle(sourceLifecycle, on: conversation.host),
                    tab.conversation?.id == conversation.id, tab.tmuxSessionName == tmuxSessionName,
                    let current = self.conversation(withID: conversation.id), self.canLaunch(current, action: .resume)
                else { return }
                guard runsInTmux else {
                    self.showError(
                        "The tab stays in the other window. JustSessions couldn't confirm that tmux on \(tab.host.nameInSentence) runs its CLI, and without tmux, closing the tab would end the CLI."
                    )
                    return
                }
                self.finishMovingTerminal(tab, from: otherStore, for: current)
            }
        }
    }

    private func finishMovingTerminal(_ tab: TerminalSession, from otherStore: ConversationStore, for conversation: Conversation) {
        if !tab.hasExited, otherStore.terminalSessions.contains(where: { $0.id == tab.id }) {
            otherStore.closingTabsWithoutRemembering {
                otherStore.closeTerminal(tab.id, endingTmuxSession: false)
            }
        }
        launch(conversation, action: .resume, engine: tab.engine)
    }
}
