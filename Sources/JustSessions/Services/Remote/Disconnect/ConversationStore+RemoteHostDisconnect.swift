import Foundation

extension ConversationStore {
    func isDisconnected(_ host: String) -> Bool {
        disconnectedRemoteHosts.isDisconnected(host)
    }

    func isDisconnected(_ host: SessionHost) -> Bool {
        host.sshDestination.map(isDisconnected) ?? false
    }

    func requestDisconnect(
        _ host: String,
        tabCloseChoices: TabCloseChoicesByHost = TabCloseChoiceSettingsStore.shared.choices,
        plainTerminalCloseChoice: PlainTerminalCloseChoice = PlainTerminalCloseChoiceSettingsStore.shared.choice
    ) {
        guard remoteHostList.hosts.contains(host), !isDisconnected(host) else { return }
        let question = SeveralTabsClosingQuestion(
            tabs: openTabsInEveryWindow(on: host).map { (need: $0.closingNeed, tabCloseChoice: tabCloseChoices.choice(for: $0.host)) },
            plainTerminalCloseChoice: plainTerminalCloseChoice
        )
        if question == .closeWithoutAsking {
            disconnectHost(host) { store, tabIDs in store.closeTabs(tabIDs, as: tabCloseChoices) }
        } else {
            hostDisconnectQuestion = HostDisconnectQuestion(host: host, question: question)
        }
    }

    func disconnectHost(_ host: String, endingTmuxSessions: Bool, connections: SSHLoginConnections = .shared) {
        hostDisconnectQuestion = nil
        disconnectHost(host, connections: connections) { store, tabIDs in
            store.closeTabs(tabIDs, endingTmuxSessions: endingTmuxSessions)
        }
    }

    func connectHost(_ host: String) {
        guard isDisconnected(host) else { return }
        let stores = storesSharingHostWork
        for store in stores {
            store.disconnectedRemoteHosts.setDisconnected(false, for: host)
            store.invalidateRemoteHostWork(on: host)
        }
        disconnectedRemoteHosts.save(to: userDefaults)
        SSHHostReachability.shared.forget(host)
        for store in stores { store.refreshRemoteHost(host) }
    }

    func connectIfDisconnected(_ host: SessionHost) {
        guard let destination = host.sshDestination, isDisconnected(destination) else { return }
        connectHost(destination)
    }

    func forgetDisconnection(from host: String) {
        guard isDisconnected(host) else { return }
        disconnectedRemoteHosts.setDisconnected(false, for: host)
        disconnectedRemoteHosts.save(to: userDefaults)
    }

    private func disconnectHost(
        _ host: String,
        connections: SSHLoginConnections = .shared,
        closingTabs: (ConversationStore, [UUID]) -> Void
    ) {
        guard remoteHostList.hosts.contains(host), !isDisconnected(host) else { return }
        let disconnection = markDisconnected(host, in: storesSharingHostWork)
        closeTabs(after: disconnection, closingTabs: closingTabs)
        for store in disconnection.stores { store.forgetRunningMarks(on: host) }
        SSHPortForwards.shared.stopAll(on: host)
        closeLoginAfterTabsClose(on: host, in: disconnection.stores, connections: connections)
    }

    private func markDisconnected(_ host: String, in stores: [ConversationStore]) -> HostMarkedDisconnected {
        for store in stores { store.disconnectedRemoteHosts.setDisconnected(true, for: host) }
        for store in stores {
            store.discardQueuedDeletions(on: .ssh(host))
            store.invalidateRemoteHostWork(on: host)
        }
        disconnectedRemoteHosts.save(to: userDefaults)
        return HostMarkedDisconnected(host: host, stores: stores)
    }

    private func closeTabs(after disconnection: HostMarkedDisconnected, closingTabs: (ConversationStore, [UUID]) -> Void) {
        for store in disconnection.stores {
            let tabs = store.terminalSessions.filter { $0.host == .ssh(disconnection.host) }
            for tab in tabs { tab.connectionEndedOnPurpose = true }
            store.closingTabsWithoutRemembering { closingTabs(store, tabs.map(\.id)) }
        }
    }

    private func forgetRunningMarks(on host: String) {
        setTmuxSessionNames([], on: .ssh(host))
        remoteDetachedSince = remoteDetachedSince.filter { $0.key.host != host }
        for conversationID in detachedCLIActivities.keys
        where conversationIndex.conversation(withID: conversationID)?.host == .ssh(host) {
            detachedCLIActivities[conversationID] = nil
        }
    }

    private func closeLoginAfterTabsClose(on host: String, in stores: [ConversationStore], connections: SSHLoginConnections) {
        for store in stores { store.sshHostsLoggedIn.remove(host) }
        let queuedCommands = DispatchGroup()
        for store in stores {
            queuedCommands.enter()
            store.tmuxCommandQueues.runAfterEarlierCommands(on: .ssh(host)) { queuedCommands.leave() }
        }
        queuedCommands.notify(queue: .global(qos: .utility)) { @Sendable in connections.disconnect(host) }
    }

    private func openTabsInEveryWindow(on host: String) -> [TerminalSession] {
        storesOfEveryWindow.flatMap { store in store.terminalSessions.filter { $0.host == .ssh(host) } }
    }
}

private struct HostMarkedDisconnected {
    let host: String
    let stores: [ConversationStore]
}
