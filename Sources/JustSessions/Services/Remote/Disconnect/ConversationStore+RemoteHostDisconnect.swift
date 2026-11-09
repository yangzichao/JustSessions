import Foundation

/// Disconnect, in an SSH host's ⋯ and right-click menus: from then on the app runs nothing on the host on its own. The
/// host isn't refreshed, checked, or asked what its CLIs do, its sign-in command isn't checked, and its tabs aren't
/// reconnected; its sessions stay listed from the last copy, read from this Mac's disk as this Mac's own are. Its
/// open tabs close in every window, as closing them together asks, and its Connect… login and port forwards end. The
/// choice is kept across launches and shared by every window; see `DisconnectedRemoteHosts`. Connect, or anything
/// that uses the host, such as resuming or starting a session there, connects it again and refreshes it.
extension ConversationStore {
    func isDisconnected(_ host: String) -> Bool {
        disconnectedRemoteHosts.isDisconnected(host)
    }

    func isDisconnected(_ host: SessionHost) -> Bool {
        host.sshDestination.map(isDisconnected) ?? false
    }

    /// Disconnect from the menu: asks about the host's open tabs first when closing them would ask, and otherwise
    /// disconnects at once, closing each tab as its host's saved choice says.
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

    /// The answer to `hostDisconnectQuestion`: the tabs close, ending their tmux sessions or leaving their CLIs running.
    func disconnectHost(_ host: String, endingTmuxSessions: Bool, connections: SSHLoginConnections = .shared) {
        hostDisconnectQuestion = nil
        disconnectHost(host, connections: connections) { store, tabIDs in
            store.closeTabs(tabIDs, endingTmuxSessions: endingTmuxSessions)
        }
    }

    /// Connect, in a disconnected host's menu, and what using the host does first: the host is refreshed in every
    /// window, as after Connect… logs in, and refreshes on its own again from then on.
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

    /// Using a host connects it again: resuming or starting a session or a terminal there, looking up a folder on
    /// it, deleting its sessions, checking it, forwarding a port, signing in, or changing its tmux prefix.
    func connectIfDisconnected(_ host: SessionHost) {
        guard let destination = host.sshDestination, isDisconnected(destination) else { return }
        connectHost(destination)
    }

    /// Removing the host forgets the choice, so the host starts connected if it is added again.
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
        let stores = storesSharingHostWork
        // Marked first, so the refresh a closing tab may start is refused.
        for store in stores { store.disconnectedRemoteHosts.setDisconnected(true, for: host) }
        for store in stores {
            store.discardQueuedDeletions(on: .ssh(host))
            store.invalidateRemoteHostWork(on: host)
        }
        disconnectedRemoteHosts.save(to: userDefaults)
        for store in stores {
            let tabs = store.terminalSessions.filter { $0.host == .ssh(host) }
            // A closed tab's ssh ends as one whose connection dropped; nothing reconnects it, Reopen Closed Tab included.
            for tab in tabs { tab.connectionEndedOnPurpose = true }
            store.closingTabsWithoutRemembering { closingTabs(store, tabs.map(\.id)) }
        }
        for store in stores { store.forgetRunningMarks(on: host) }
        SSHPortForwards.shared.stopAll(on: host)
        closeLoginAfterTabsClose(on: host, in: stores, connections: connections)
    }

    /// The host's running marks are as of its last refresh, which no longer comes, so no session shows as running or
    /// waiting there until the host is connected and refreshed again. A tab closed with Keep running marked its
    /// session too.
    private func forgetRunningMarks(on host: String) {
        setTmuxSessionNames([], on: .ssh(host))
        remoteDetachedSince = remoteDetachedSince.filter { $0.key.host != host }
        for conversationID in detachedCLIActivities.keys
        where conversationIndex.conversation(withID: conversationID)?.host == .ssh(host) {
            detachedCLIActivities[conversationID] = nil
        }
    }

    /// The host's Connect… login, when it has one, closes once each window's queued tmux commands have run, so End
    /// sessions' kills still go through it. The refresh that closing a login starts is refused while the host is
    /// disconnected.
    private func closeLoginAfterTabsClose(on host: String, in stores: [ConversationStore], connections: SSHLoginConnections) {
        for store in stores { store.sshHostsLoggedIn.remove(host) }
        let queuedCommands = DispatchGroup()
        for store in stores {
            queuedCommands.enter()
            store.tmuxCommandQueues.run(on: .ssh(host)) { queuedCommands.leave() }
        }
        // Off the main actor, as the closure runs on that queue.
        queuedCommands.notify(queue: .global(qos: .utility)) { @Sendable in connections.disconnect(host) }
    }

    /// The host's open tabs across the app's windows.
    private func openTabsInEveryWindow(on host: String) -> [TerminalSession] {
        storesOfEveryWindow.flatMap { store in store.terminalSessions.filter { $0.host == .ssh(host) } }
    }
}
