import Foundation

extension ConversationStore {
    func logIn(
        to host: String,
        login: SSHLogin = SSHLogin(),
        asking ask: @escaping @Sendable (SSHAskpassQuestion) async -> String?
    ) async -> SSHLoginOutcome {
        guard sshHostsLoggingIn.insert(host).inserted else { return .cancelled }
        let outcome = await login.logIn(to: host, ask: ask)
        sshHostsLoggingIn.remove(host)
        if outcome == .loggedIn {
            SSHHostReachability.shared.forget(host)
            for store in storesOfEveryWindow { store.loginOpened(on: host) }
            NotificationCenter.default.post(name: RemoteTabReconnector.loginOpenedNotification, object: host)
        }
        return outcome
    }

    func logInFromHeading(to host: String, asking ask: @escaping @Sendable (SSHAskpassQuestion) async -> String?) {
        Task {
            guard case .failed(let problem) = await logIn(to: host, asking: ask) else { return }
            show(StoreAlert(title: "Couldn't log in to \(host)", message: problem.loginFailureExplanation(host: host)))
        }
    }

    func closeLogin(on host: String, connections: SSHLoginConnections = .shared) {
        for tab in storesOfEveryWindow.flatMap(\.terminalSessions)
        where tab.host == .ssh(host) && tab.command.goesThroughSSHLogin {
            tab.connectionEndedOnPurpose = true
        }
        SSHPortForwards.shared.loginEnding(on: host)
        connections.disconnect(host)
        for store in storesOfEveryWindow { store.loginClosed(on: host) }
    }

    func noteLoginState(on host: String, refreshProblem: SSHConnectionProblem?, connections: SSHLoginConnections = .shared) {
        setMembershipPublishingOnlyChanges(
            of: host, in: \.sshHostsNeedingLogIn, to: refreshProblem?.isFixedByLoggingIn == true)
        if !connections.isLoggedIn(host) {
            setMembershipPublishingOnlyChanges(of: host, in: \.sshHostsLoggedIn, to: false)
            connections.forgetEndedLogin(of: host)
        }
    }

    private func setMembershipPublishingOnlyChanges(
        of host: String,
        in hosts: ReferenceWritableKeyPath<ConversationStore, Set<String>>,
        to isMember: Bool
    ) {
        guard self[keyPath: hosts].contains(host) != isMember else { return }
        if isMember { self[keyPath: hosts].insert(host) } else { self[keyPath: hosts].remove(host) }
    }

    func forgetLoginState(on host: String) {
        sshHostsNeedingLogIn.remove(host)
        sshHostsLoggingIn.remove(host)
        sshHostsLoggedIn.remove(host)
    }

    private func loginOpened(on host: String) {
        sshHostsLoggedIn.insert(host)
        sshHostsNeedingLogIn.remove(host)
        if remoteHostList.hosts.contains(host) { refreshRemoteHost(host) }
    }

    private func loginClosed(on host: String) {
        sshHostsLoggedIn.remove(host)
        if remoteHostList.hosts.contains(host) { refreshRemoteHost(host) }
    }

    var storesOfEveryWindow: [ConversationStore] {
        windowRegistry.stores
    }
}
