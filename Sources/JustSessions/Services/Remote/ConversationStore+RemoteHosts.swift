import Foundation

extension ConversationStore {
    @discardableResult
    func refreshRemoteHost(
        _ host: String,
        discovery: RemoteSessionDiscovery? = nil
    ) -> RemoteHostRefreshStart {
        if let refusal = remoteHostRefreshRefusal(on: host) { return .refused(refusal) }
        let discovery = discovery ?? remoteSessionDiscovery
        let token = remoteHostWork.beginRefresh(on: host, previousStatus: hostRefreshStatuses[.ssh(host)])
        let refreshAskedAt = windowRegistry.latestRemoteHostCopies.noteRefreshAsked()
        let coordinator = windowRegistry.hostSessionWork
        hostRefreshStatuses[.ssh(host)] = .refreshing
        remoteHostCopies.noteStart(of: host)
        let task: Task<Void, Never> = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try await coordinator.withAccess(to: [.ssh(host)]) { [weak self] in
                    try Task.checkCancellation()
                    let turn = await self?.remoteHostRefreshTurn(token, on: host, into: discovery.mirror, askedAt: refreshAskedAt)
                    guard let turn else { throw CancellationError() }
                    switch turn {
                    case .take(let outcome):
                        try await self?.takeAnotherWindowsCopy(outcome, host: host, token: token, discovery: discovery)
                    case .copy(let copyStartedAt):
                        try await RemoteHostRefreshCopy(
                            store: self, host: host, token: token, discovery: discovery, startedAt: copyStartedAt
                        ).copyNotingItsEnd()
                    }
                }
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled { await self?.failRemoteHostRefresh(host, token: token, error: error) }
            }
            await self?.completeRemoteHostRefreshTask(host, token: token, wasCancelled: Task.isCancelled)
        }
        remoteHostWork.keep(task, on: host, token: token)
        return .started(task)
    }

    private func remoteHostRefreshRefusal(on host: String) -> RemoteHostRefreshStart.Refusal? {
        if isTearingDownWorkspace { return .workspaceClosing }
        if !remoteHostList.hosts.contains(host) { return .hostNotListed }
        if isDisconnected(host) { return .hostDisconnected }
        if deferRefreshWhileDeleting(on: .ssh(host)) { return .deferredUntilDeletionEnds }
        if hostRefreshStatuses[.ssh(host)] == .refreshing { return .alreadyRefreshing }
        return nil
    }

    func isCurrentRemoteHostRefresh(_ token: RemoteHostWork.Token, on host: String) -> Bool {
        !isTearingDownWorkspace && remoteHostList.hosts.contains(host) && !isDisconnected(host)
            && remoteHostWork.isCurrent(token, on: host)
    }

    private func remoteHostRefreshTurn(
        _ token: RemoteHostWork.Token, on host: String, into mirror: RemoteSessionMirror,
        askedAt refreshAskedAt: LatestRemoteHostCopies.Moment
    ) -> LatestRemoteHostCopies.Turn? {
        guard isCurrentRemoteHostRefresh(token, on: host) else { return nil }
        return windowRegistry.latestRemoteHostCopies.turn(on: host, into: mirror, askedAt: refreshAskedAt)
    }

    fileprivate func noteRemoteHostCopyFailed(
        _ host: String,
        token: RemoteHostWork.Token,
        mirror: RemoteSessionMirror,
        copyStartedAt: LatestRemoteHostCopies.Moment,
        error: any Error
    ) {
        guard isCurrentRemoteHostRefresh(token, on: host) else { return }
        windowRegistry.latestRemoteHostCopies.noteCopyEnded(
            on: host, into: mirror, startedAt: copyStartedAt, outcome: .failed(error)
        )
    }

    fileprivate func applyRemoteRefreshConversations(
        _ conversations: [Conversation], host: String, token: RemoteHostWork.Token, step: RemoteSessionCopyStep? = nil
    ) {
        guard isCurrentRemoteHostRefresh(token, on: host) else { return }
        if let step {
            applyRemoteHostConversations(conversations, of: step, host: host)
        } else {
            applyRemoteHostConversations(conversations, host: host)
        }
    }

    fileprivate func finishRemoteHostRefresh(
        _ host: String,
        token: RemoteHostWork.Token,
        status: RemoteHostStatus?,
        discovery: RemoteSessionDiscovery,
        copyStartedAt: LatestRemoteHostCopies.Moment
    ) {
        guard isCurrentRemoteHostRefresh(token, on: host) else { return }
        let refreshedAt = Date.now
        windowRegistry.latestRemoteHostCopies.noteCopyEnded(
            on: host, into: discovery.mirror, startedAt: copyStartedAt, outcome: .copied(refreshedAt: refreshedAt, status: status)
        )
        if let status {
            setTmuxSessionNames(status.tmuxSessionNames, on: .ssh(host))
            setTmuxServerProblem(status.tmuxServerProblem, on: host)
            if let locations = status.cliLocations {
                RemoteHostCLILocations.shared.setLocations(locations, on: host)
                setInstalledProviders(Set(locations.keys), on: .ssh(host))
            }
            checkClaudeSessionIDFlagIfUnanswered(on: host)
        }
        setRemoteHostRefreshStatus(.refreshed(refreshedAt), host: host)
        noteLoginState(on: host, refreshProblem: nil)
        shareRemoteHostCopy(host, refreshedAt: refreshedAt, status: status, discovery: discovery)
        if let status { checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: status.installedProviders != nil) }
    }

    func failRemoteHostRefresh(_ host: String, token: RemoteHostWork.Token, error: any Error, checksShellStartup: Bool = true) {
        guard isCurrentRemoteHostRefresh(token, on: host) else { return }
        setRemoteHostRefreshStatus(.failed(error.localizedDescription), host: host)
        if case .sshFailed(_, let problem)? = error as? RemoteSessionMirrorError {
            noteLoginState(on: host, refreshProblem: problem)
            if problem == .windowsHost { return }
        }
        if checksShellStartup { checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: false) }
    }

    private func completeRemoteHostRefreshTask(_ host: String, token: RemoteHostWork.Token, wasCancelled: Bool) {
        defer { resumeQueuedHostWorkInAllWindows() }
        guard remoteHostWork.isCurrent(token, on: host) else { return }
        if wasCancelled, hostRefreshStatuses[.ssh(host)] == .refreshing {
            hostRefreshStatuses[.ssh(host)] = remoteHostWork.previousStatus(on: host)
            remoteSessionCopySteps[.ssh(host)] = nil
        }
        remoteHostWork.finishRefresh(on: host, token: token)
    }

    func listRemoteHostFromMirror(_ host: String) {
        guard !isTearingDownWorkspace, remoteHostList.hosts.contains(host), hostRefreshStatuses[.ssh(host)] != .refreshing
        else { return }
        let token = remoteHostWork.beginRead(on: host)
        let discovery = remoteSessionDiscovery
        let coordinator = windowRegistry.hostSessionWork
        Task.detached(priority: .userInitiated) { [weak self] in
            try? await coordinator.withAccess(to: [.ssh(host)]) { [weak self] in
                guard let mirroredConversations = try? discovery.readMirror(host: host) else { return }
                await self?.applyRemoteMirrorListing(mirroredConversations, host: host, token: token)
            }
        }
    }

    private func applyRemoteMirrorListing(_ conversations: [Conversation], host: String, token: RemoteHostWork.Token) {
        guard !isTearingDownWorkspace, remoteHostList.hosts.contains(host), remoteHostWork.isCurrentRead(token, on: host) else { return }
        applyRemoteHostConversations(conversations, host: host, discardMissingReopeningTabs: false)
    }

    func connectionProblem(
        on host: String,
        check: RemoteHostConnectionCheck = RemoteHostConnectionCheck()
    ) async -> SSHConnectionProblem? {
        SSHHostReachability.shared.forget(host)
        return await Task.detached(priority: .userInitiated) { check.problem(connectingTo: host) }.value
    }

    func sameMachineCheck(for host: String) async -> SSHHostSameMachineCheck {
        let listedHosts = remoteHostList.hosts
        return await Task.detached(priority: .userInitiated) {
            SSHHostSameMachineCheck.check(host: host, listedHosts: listedHosts)
        }.value
    }

    @discardableResult
    func addRemoteHost(_ proposedHost: String) -> Bool {
        guard remoteHostList.add(proposedHost), let host = RemoteHostList.normalizedHost(proposedHost) else { return false }
        invalidateRemoteHostWork(on: host)
        remoteHostList.save(to: userDefaults)
        messageIndexer.restoreHost(.ssh(host))
        refreshRemoteHost(host)
        return true
    }

    func removeRemoteHost(_ host: String, mirror: RemoteSessionMirror = RemoteSessionMirror()) {
        let cancelled = storesSharingHostWork.compactMap { store in
            store.discardQueuedDeletions(on: .ssh(host))
            return store.invalidateRemoteHostWork(on: host)
        }
        let generation = remoteHostWork.lifecycle(on: host)
        let coordinator = windowRegistry.hostSessionWork
        remoteHostList.remove(host)
        closeLogin(on: host)
        forgetDisconnection(from: host)
        SSHPortForwards.shared.stopAll(on: host)
        RemoteSignIns.shared.forget(host)
        forgetLoginState(on: host)
        messageIndexer.removeHost(.ssh(host))
        remoteHostList.save(to: userDefaults)
        remoteHostsUsingTmuxPrefix.setUsesTmuxPrefix(false, for: host)
        remoteHostsUsingTmuxPrefix.save(to: userDefaults)
        tabCloseChoiceSettingsStore.forgetSSHHost(host)
        forgetRemoteShellStartup(on: host)
        forgetHostChecks(on: host)
        hostRefreshStatuses.removeValue(forKey: .ssh(host))
        remoteHostCopies.forget(host)
        windowRegistry.latestRemoteHostCopies.forget(host)
        remoteSessionCopySteps.removeValue(forKey: .ssh(host))
        tmuxSessionNamesByHost.removeValue(forKey: .ssh(host))
        installedProvidersByHost.removeValue(forKey: .ssh(host))
        RemoteHostCLILocations.shared.forgetLocations(on: host)
        replaceConversations(on: .ssh(host), with: [])
        Task.detached(priority: .utility) { [weak self] in
            for task in cancelled { await task.value }
            try? await coordinator.withAccess(to: [.ssh(host)]) { [weak self] in
                guard await self?.canRemoveRemoteMirror(host, generation: generation) == true else { return }
                mirror.removeMirror(host: host)
            }
        }
        resumeQueuedHostWorkInAllWindows()
    }

    private func canRemoveRemoteMirror(_ host: String, generation: UInt64) -> Bool {
        !remoteHostList.hosts.contains(host) && remoteHostWork.lifecycle(on: host) == generation
    }

    func applyRemoteHostConversations(
        _ hostConversations: [Conversation],
        host: String,
        discardMissingReopeningTabs: Bool = true
    ) {
        guard remoteHostList.hosts.contains(host) else { return }
        replaceConversations(on: .ssh(host), with: hostConversations, discardMissingReopeningTabs: discardMissingReopeningTabs)
        linkWaitingTabsToPreassignedSessions(on: .ssh(host))
        linkWaitingTabsByAppearance(on: .ssh(host))
    }

    func applyRemoteHostConversations(_ toolConversations: [Conversation], of step: RemoteSessionCopyStep, host: String) {
        guard remoteHostList.hosts.contains(host) else { return }
        if listsSameSessions(toolConversations, of: step.provider, on: .ssh(host)) {
            if step.isLast, pendingTabReopening.waitingTabs.contains(where: { $0.tab.host == .ssh(host) }) {
                reopenWaitingTabs(on: .ssh(host))
            }
            return
        }
        let otherToolsConversations = (conversations + subagentConversations)
            .filter { $0.host == .ssh(host) && $0.provider != step.provider }
        applyRemoteHostConversations(
            otherToolsConversations + toolConversations,
            host: host,
            discardMissingReopeningTabs: step.isLast
        )
    }

    private func listsSameSessions(_ copied: [Conversation], of provider: ConversationProvider, on host: SessionHost) -> Bool {
        var copiedByID = Dictionary(copied.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard copiedByID.count == copied.count else { return false }
        for conversation in conversations where conversation.host == host && conversation.provider == provider {
            guard copiedByID.removeValue(forKey: conversation.id) == conversation else { return false }
        }
        for conversation in subagentConversations where conversation.host == host && conversation.provider == provider {
            guard copiedByID.removeValue(forKey: conversation.id) == conversation else { return false }
        }
        return copiedByID.isEmpty
    }

    fileprivate func setRemoteSessionCopyStep(_ step: RemoteSessionCopyStep, host: String, token: RemoteHostWork.Token) {
        guard isCurrentRemoteHostRefresh(token, on: host) else { return }
        remoteSessionCopySteps[.ssh(host)] = step
    }

    func setRemoteHostRefreshStatus(_ status: HostRefreshStatus, host: String) {
        guard remoteHostList.hosts.contains(host) else { return }
        hostRefreshStatuses[.ssh(host)] = status
        if case .failed = status {
            remoteHostCopies.noteEnd(of: host, failed: true)
        } else {
            remoteHostCopies.noteEnd(of: host, failed: false)
        }
        remoteSessionCopySteps.removeValue(forKey: .ssh(host))
        resumeQueuedHostWorkInAllWindows()
    }
}

private struct RemoteHostRefreshCopy: Sendable {
    weak let store: ConversationStore?
    let host: String
    let token: RemoteHostWork.Token
    let discovery: RemoteSessionDiscovery
    let startedAt: LatestRemoteHostCopies.Moment

    func copyNotingItsEnd() async throws {
        do {
            try await copy()
        } catch {
            if !(error is CancellationError), !Task.isCancelled {
                await store?.noteRemoteHostCopyFailed(
                    host, token: token, mirror: discovery.mirror, copyStartedAt: startedAt, error: error
                )
            }
            throw error
        }
    }

    private func copy() async throws {
        if let mirrored = try? discovery.readMirror(host: host), !mirrored.isEmpty {
            await store?.applyRemoteRefreshConversations(mirrored, host: host, token: token)
        }
        try Task.checkCancellation()
        try await discovery.discoverToolByTool(
            host: host,
            copying: { step in await store?.setRemoteSessionCopyStep(step, host: host, token: token) },
            copied: { step, conversations in
                await store?.applyRemoteRefreshConversations(conversations, host: host, token: token, step: step)
            }
        )
        try Task.checkCancellation()
        guard await store?.isCurrentRemoteHostRefresh(token, on: host) == true else { throw CancellationError() }
        let status = discovery.status(host)
        try Task.checkCancellation()
        await store?.finishRemoteHostRefresh(host, token: token, status: status, discovery: discovery, copyStartedAt: startedAt)
    }
}
