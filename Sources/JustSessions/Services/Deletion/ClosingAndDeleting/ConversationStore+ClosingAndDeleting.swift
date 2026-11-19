import Foundation

/// Close and delete, for a session a tab shows, in any window, or whose CLI still runs in tmux: Delete session
/// leaves such a session alone, as its CLI could write its files again. This closes the tabs, ends the CLI, waits
/// for it to exit, then deletes the session as Delete session does.
extension ConversationStore {
    /// How long a CLI gets to exit before its session is deleted anyway.
    static let cliExitTimeoutBeforeDeletion = 5

    /// What Close and delete ends first; nil when nothing runs the session and Delete session can delete it.
    func cliEndingBeforeDeletion(of conversation: Conversation) -> SessionCLIEndingBeforeDeletion? {
        if terminalSessions.contains(where: { $0.conversation?.id == conversation.id }) || hasTerminalInAnotherWindow(for: conversation) {
            return .closingTab
        }
        return isRunningInTmux(conversation) ? .endingCLIInTmux : nil
    }

    func closeAndDelete(_ conversation: Conversation, remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        endCLIs(of: [conversation], remoteRunner: remoteRunner) { $0.delete(conversation) }
    }

    /// Delete for a multi-selection or a project: deletes the sessions nothing runs at once, and closes the tabs and
    /// ends the CLIs of the others, as Close and delete does, deleting them once their CLIs have exited. They join
    /// the first deletion while it still runs.
    func closeAndDeleteConversations(
        _ candidateConversations: [Conversation],
        remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()
    ) {
        let deletable = deletionPlan(for: candidateConversations, endingTheirCLIs: true).deletableConversations
        let running = deletable.filter { cliEndingBeforeDeletion(of: $0) != nil }
        let runningIDs = Set(running.map(\.id))
        deleteConversations(deletable.filter { !runningIDs.contains($0.id) })
        guard !running.isEmpty else { return }
        endCLIs(of: running, remoteRunner: remoteRunner) { $0.deleteConversations(running) }
    }

    /// Closes the sessions' tabs in every window and ends their CLIs, then, once the CLIs have exited, runs `delete`.
    private func endCLIs(
        of conversations: [Conversation],
        remoteRunner: RemoteHostCommandRunner,
        then delete: @escaping @MainActor (ConversationStore) -> Void
    ) {
        let cliExits = DispatchGroup()
        var endedTmuxNamesByHost: [SessionHost: Set<String>] = [:]
        for conversation in conversations {
            var endedTmuxNames: Set<String> = []
            for store in otherWindowStores {
                endedTmuxNames.formUnion(store.closeTabsAndEndCLI(of: conversation, cliExits: cliExits, remoteRunner: remoteRunner))
            }
            endedTmuxNames.formUnion(
                closeTabsAndEndCLI(
                    of: conversation, alsoEndingTmuxSessionWithoutTab: true, cliExits: cliExits, remoteRunner: remoteRunner
                ))
            endedTmuxNamesByHost[conversation.host, default: []].formUnion(endedTmuxNames)
        }
        cliExits.notify(queue: .main) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task {
                    await self.waitForRefreshes(forgetting: endedTmuxNamesByHost)
                    delete(self)
                }
            }
        }
    }

    /// Closes this window's tabs of the session and ends the tmux sessions their CLIs run in, after this window's
    /// tmux commands for the host already queued, such as the rename that gave a new session's tmux session its
    /// name. `cliExits` is left once the CLIs have exited. Returns the tmux sessions it ends.
    private func closeTabsAndEndCLI(
        of conversation: Conversation,
        alsoEndingTmuxSessionWithoutTab: Bool = false,
        cliExits: DispatchGroup,
        remoteRunner: RemoteHostCommandRunner
    ) -> Set<String> {
        let host = conversation.host
        let tabs = terminalSessions.filter { $0.conversation?.id == conversation.id }
        let tmuxNameWithoutTab =
            alsoEndingTmuxSessionWithoutTab && isRunningInTmux(conversation)
            ? [TmuxSessionName.forConversation(conversation)]
            : []
        let tmuxNames = Set(tabs.compactMap(\.tmuxSessionName) + tmuxNameWithoutTab)
        guard !tabs.isEmpty || !tmuxNames.isEmpty else { return [] }
        // Read before the tabs close. A CLI in tmux is the pane's process; a tab without tmux runs its CLI itself.
        let thisMacCLIProcessIDs: Set<Int32> =
            host == .thisMac
            ? Set(tabs.map(\.cliProcessID) + tmuxNames.compactMap { thisMacTmuxPaneProcessIDs[$0] }).filter { $0 > 0 }
            : []
        // The session is about to be deleted, so Reopen Closed Tab has nothing to bring back.
        closingTabsWithoutRemembering {
            for tab in tabs { closeTerminal(tab.id) }
        }
        tmuxSessionNamesByHost[host]?.subtract(tmuxNames)
        let timeoutSeconds = Self.cliExitTimeoutBeforeDeletion
        cliExits.enter()
        switch host {
        case .thisMac:
            for name in tmuxNames { thisMacTmuxPaneProcessIDs[name] = nil }
            let tmuxServer = commandResolver.thisMacTmuxServer()
            tmuxCommandQueues.run(on: host) {
                for name in tmuxNames { tmuxServer?.killSession(named: name) }
                ProcessExitWaiting.waitUntilExited(thisMacCLIProcessIDs, timeout: TimeInterval(timeoutSeconds))
                cliExits.leave()
            }
        case .ssh(let destination):
            tmuxCommandQueues.run(on: host) {
                for name in tmuxNames {
                    let command = RemoteTmuxCommands.killSessionWaitingForCLIExitCommand(
                        name, on: destination, timeoutSeconds: timeoutSeconds)
                    _ = remoteRunner.run(destination, command, TimeInterval(timeoutSeconds + 30))
                }
                cliExits.leave()
            }
        }
        return tmuxNames
    }

    /// A refresh of a host that started before its CLIs ended may list them as running still, and a deletion would
    /// then skip their sessions. So this waits for those refreshes, then forgets the ended tmux sessions. A refresh
    /// that starts later finds them gone.
    private func waitForRefreshes(forgetting endedTmuxNamesByHost: [SessionHost: Set<String>]) async {
        while endedTmuxNamesByHost.keys.contains(where: { hostRefreshStatuses[$0] == .refreshing }) {
            try? await Task.sleep(for: .milliseconds(100))
        }
        for (host, endedTmuxNames) in endedTmuxNamesByHost {
            tmuxSessionNamesByHost[host]?.subtract(endedTmuxNames)
        }
    }
}
