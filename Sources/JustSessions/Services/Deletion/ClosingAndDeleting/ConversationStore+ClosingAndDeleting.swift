import Foundation

extension ConversationStore {
    static let cliExitTimeoutBeforeDeletion = 5

    func cliEndingBeforeDeletion(of conversation: Conversation) -> SessionCLIEndingBeforeDeletion? {
        if terminalSessions.contains(where: { $0.conversation?.id == conversation.id }) || hasTerminalInAnotherWindow(for: conversation) {
            return .closingTab
        }
        return isRunningInTmux(conversation) ? .endingCLIInTmux : nil
    }

    func closeAndDelete(_ conversation: Conversation, remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        endCLIs(of: [conversation], remoteRunner: remoteRunner) { $0.delete(conversation) }
    }

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
                    await self.waitForRefreshesStartedBeforeTheCLIsEnded(thenForget: endedTmuxNamesByHost)
                    delete(self)
                }
            }
        }
    }

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
        let thisMacCLIProcessIDs = readThisMacCLIProcessIDsThenClose(tabs, alongWith: tmuxNames, on: host)
        tmuxSessionNamesByHost[host]?.subtract(tmuxNames)
        let timeoutSeconds = Self.cliExitTimeoutBeforeDeletion
        cliExits.enter()
        switch host {
        case .thisMac:
            for name in tmuxNames { thisMacTmuxPaneProcessIDs[name] = nil }
            let tmuxServer = commandResolver.thisMacTmuxServer()
            tmuxCommandQueues.runAfterEarlierCommands(on: host) {
                for name in tmuxNames { tmuxServer?.killSession(named: name) }
                ProcessExitWaiting.waitUntilExited(thisMacCLIProcessIDs, timeout: TimeInterval(timeoutSeconds))
                cliExits.leave()
            }
        case .ssh(let destination):
            tmuxCommandQueues.runAfterEarlierCommands(on: host) {
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

    private func readThisMacCLIProcessIDsThenClose(
        _ tabs: [TerminalSession], alongWith tmuxNames: Set<String>, on host: SessionHost
    ) -> Set<Int32> {
        let thisMacCLIProcessIDs: Set<Int32> =
            host == .thisMac
            ? Set(tabs.map(\.cliProcessID) + tmuxNames.compactMap { thisMacTmuxPaneProcessIDs[$0] }).filter { $0 > 0 }
            : []
        closingTabsWithoutRemembering {
            for tab in tabs { closeTerminal(tab.id) }
        }
        return thisMacCLIProcessIDs
    }

    private static let unfinishedRefreshPollInterval: Duration = .milliseconds(100)

    private func waitForRefreshesStartedBeforeTheCLIsEnded(thenForget endedTmuxNamesByHost: [SessionHost: Set<String>]) async {
        while endedTmuxNamesByHost.keys.contains(where: { hostRefreshStatuses[$0] == .refreshing }) {
            try? await Task.sleep(for: Self.unfinishedRefreshPollInterval)
        }
        for (host, endedTmuxNames) in endedTmuxNamesByHost {
            tmuxSessionNamesByHost[host]?.subtract(endedTmuxNames)
        }
    }
}
