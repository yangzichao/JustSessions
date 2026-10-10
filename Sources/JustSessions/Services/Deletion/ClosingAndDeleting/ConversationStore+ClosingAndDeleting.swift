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
        let cliExits = DispatchGroup()
        var endedTmuxNames: Set<String> = []
        for store in otherWindowStores {
            endedTmuxNames.formUnion(store.closeTabsAndEndCLI(of: conversation, cliExits: cliExits, remoteRunner: remoteRunner))
        }
        endedTmuxNames.formUnion(closeTabsAndEndCLI(
            of: conversation, alsoEndingTmuxSessionWithoutTab: true, cliExits: cliExits, remoteRunner: remoteRunner
        ))
        cliExits.notify(queue: .main) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.deleteOnceRefreshed(conversation, endedTmuxNames: endedTmuxNames) }
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
        let tmuxNameWithoutTab = alsoEndingTmuxSessionWithoutTab && isRunningInTmux(conversation)
            ? [TmuxSessionName.forConversation(conversation)]
            : []
        let tmuxNames = Set(tabs.compactMap(\.tmuxSessionName) + tmuxNameWithoutTab)
        guard !tabs.isEmpty || !tmuxNames.isEmpty else { return [] }
        // Read before the tabs close. A CLI in tmux is the pane's process; a tab without tmux runs its CLI itself.
        let thisMacCLIProcessIDs: Set<Int32> = host == .thisMac
            ? Set(tabs.map(\.cliProcessID) + tmuxNames.compactMap { thisMacTmuxPaneProcessIDs[$0] }).filter { $0 > 0 }
            : []
        for tab in tabs { closeTerminal(tab.id) }
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
                    let command = RemoteTmuxCommands.killSessionWaitingForCLIExitCommand(name, on: destination, timeoutSeconds: timeoutSeconds)
                    _ = remoteRunner.run(destination, command, TimeInterval(timeoutSeconds + 30))
                }
                cliExits.leave()
            }
        }
        return tmuxNames
    }

    /// A refresh of the host that started before the CLI ended may list it as running still, and a deletion would
    /// then skip the session. So this waits for that refresh, then forgets the ended tmux sessions. A refresh that
    /// starts later finds them gone.
    private func deleteOnceRefreshed(_ conversation: Conversation, endedTmuxNames: Set<String>) async {
        while hostRefreshStatuses[conversation.host] == .refreshing {
            try? await Task.sleep(for: .milliseconds(100))
        }
        tmuxSessionNamesByHost[conversation.host]?.subtract(endedTmuxNames)
        delete(conversation)
    }
}
