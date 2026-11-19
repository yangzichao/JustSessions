import Foundation

extension ConversationStore {
    func shareRemoteHostCopy(
        _ host: String,
        refreshedAt: Date,
        status: RemoteHostStatus?,
        discovery: RemoteSessionDiscovery
    ) {
        for store in otherWindowStores {
            store.listRemoteHostCopy(host, refreshedAt: refreshedAt, status: status, discovery: discovery)
        }
    }

    func listRemoteHostCopy(
        _ host: String,
        refreshedAt: Date,
        status: RemoteHostStatus?,
        discovery: RemoteSessionDiscovery
    ) {
        guard canListRemoteHostCopy(host) else { return }
        if case .refreshed(let current)? = hostRefreshStatuses[.ssh(host)], refreshedAt < current { return }
        startReadingRemoteHostCopy(host, refreshedAt: refreshedAt, status: status, discovery: discovery)
    }

    private func startReadingRemoteHostCopy(
        _ host: String, refreshedAt: Date, status: RemoteHostStatus?, discovery: RemoteSessionDiscovery
    ) {
        guard canListRemoteHostCopy(host), let token = remoteHostWork.beginReadIfNewestCopy(on: host, copiedAt: refreshedAt) else { return }
        let coordinator = windowRegistry.hostSessionWork
        Task.detached(priority: .userInitiated) { [weak self] in
            try? await coordinator.withAccess(to: [.ssh(host)]) { [weak self] in
                guard await self?.canReadRemoteHostCopy(host, token: token) == true else { return }
                let hostConversations = try discovery.readMirror(host: host)
                await self?.applyRemoteHostCopy(
                    host, hostConversations: hostConversations, refreshedAt: refreshedAt, status: status, token: token)
            }
        }
    }

    private func canReadRemoteHostCopy(_ host: String, token: RemoteHostWork.Token) -> Bool {
        canListRemoteHostCopy(host) && remoteHostWork.isCurrentRead(token, on: host)
    }

    private func applyRemoteHostCopy(
        _ host: String,
        hostConversations: [Conversation],
        refreshedAt: Date,
        status: RemoteHostStatus?,
        token: RemoteHostWork.Token
    ) {
        guard canListRemoteHostCopy(host), remoteHostWork.isCurrentRead(token, on: host) else { return }
        applyRemoteHostConversations(hostConversations, host: host)
        showRemoteHostStatusOfAnotherWindowsCopy(status, on: host)
        hostRefreshStatuses[.ssh(host)] = .refreshed(refreshedAt)
        noteLoginState(on: host, refreshProblem: nil)
    }

    nonisolated func takeAnotherWindowsCopy(
        _ outcome: LatestRemoteHostCopies.Outcome, host: String, token: RemoteHostWork.Token, discovery: RemoteSessionDiscovery
    ) async throws {
        switch outcome {
        case .copied(let refreshedAt, let status):
            let hostConversations = try discovery.readMirror(host: host)
            try Task.checkCancellation()
            await finishRefreshWithAnotherWindowsCopy(
                host, token: token, hostConversations: hostConversations, refreshedAt: refreshedAt, status: status
            )
        case .failed(let error):
            await failRemoteHostRefresh(host, token: token, error: error, checksShellStartup: false)
        }
    }

    private func finishRefreshWithAnotherWindowsCopy(
        _ host: String,
        token: RemoteHostWork.Token,
        hostConversations: [Conversation],
        refreshedAt: Date,
        status: RemoteHostStatus?
    ) {
        guard isCurrentRemoteHostRefresh(token, on: host) else { return }
        applyRemoteHostConversations(hostConversations, host: host)
        showRemoteHostStatusOfAnotherWindowsCopy(status, on: host)
        setRemoteHostRefreshStatus(.refreshed(refreshedAt), host: host)
        noteLoginState(on: host, refreshProblem: nil)
    }

    private func showRemoteHostStatusOfAnotherWindowsCopy(_ status: RemoteHostStatus?, on host: String) {
        guard let status else { return }
        setTmuxSessionNames(status.tmuxSessionNames, on: .ssh(host))
        setTmuxServerProblem(status.tmuxServerProblem, on: host)
        if let installedProviders = status.installedProviders {
            setInstalledProviders(installedProviders, on: .ssh(host))
        }
    }

    private func canListRemoteHostCopy(_ host: String) -> Bool {
        !isTearingDownWorkspace && remoteHostList.hosts.contains(host) && !isDisconnected(host)
            && hostRefreshStatuses[.ssh(host)] != .refreshing
            && !isDeleting(on: .ssh(host))
    }
}
