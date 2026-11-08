import Foundation

/// Sessions on SSH hosts. Each host is copied into a local mirror in the background, apart from this Mac's scan,
/// so a slow or unreachable host never holds up the rest of the list.
extension ConversationStore {
    /// Returns the refresh's task, or nil when none started: the host is disconnected (see
    /// `ConversationStore+RemoteHostDisconnect`), is refreshing already, or a deletion from it runs and the refresh
    /// waits for it. Copies with `discovery`, or else the store's.
    @discardableResult
    func refreshRemoteHost(
        _ host: String,
        discovery: RemoteSessionDiscovery? = nil
    ) -> Task<Void, Never>? {
        guard !isTearingDownWorkspace, remoteHostList.hosts.contains(host), !isDisconnected(host),
              !deferRefreshWhileDeleting(on: .ssh(host)),
              hostRefreshStatuses[.ssh(host)] != .refreshing else { return nil }
        let discovery = discovery ?? remoteSessionDiscovery
        let token = remoteHostWork.beginRefresh(on: host, previousStatus: hostRefreshStatuses[.ssh(host)])
        let configuredHosts = Array(Set(storesOfEveryWindow.flatMap { $0.remoteHostList.hosts }))
        let coordinator = windowRegistry.hostSessionWork
        hostRefreshStatuses[.ssh(host)] = .refreshing
        remoteHostCopies.noteStart(of: host)
        let task: Task<Void, Never> = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try await coordinator.withAccess(to: [.ssh(host)]) { [weak self] in
                    try Task.checkCancellation()
                    guard await self?.isCurrentRemoteHostRefresh(token, on: host) == true else { throw CancellationError() }
                    discovery.mirror.migrateLegacyMirrors(for: configuredHosts)
                    // The last copy lists right away; the host may be slow or offline.
                    if let mirrored = try? discovery.readMirror(host: host), !mirrored.isEmpty {
                        await self?.applyRemoteRefreshConversations(mirrored, host: host, token: token)
                    }
                    try Task.checkCancellation()
                    try await discovery.discoverToolByTool(
                        host: host,
                        copying: { [weak self] step in await self?.setRemoteSessionCopyStep(step, host: host, token: token) },
                        copied: { [weak self] step, conversations in
                            await self?.applyRemoteRefreshConversations(conversations, host: host, token: token, step: step)
                        }
                    )
                    try Task.checkCancellation()
                    guard await self?.isCurrentRemoteHostRefresh(token, on: host) == true else { throw CancellationError() }
                    let status = discovery.status(host)
                    try Task.checkCancellation()
                    await self?.finishRemoteHostRefresh(host, token: token, status: status, discovery: discovery)
                }
            } catch is CancellationError {
                // Disconnect/removal already invalidated the generation and restored the last completed status.
            } catch {
                if !Task.isCancelled { await self?.failRemoteHostRefresh(host, token: token, error: error) }
            }
            await self?.completeRemoteHostRefreshTask(host, token: token, wasCancelled: Task.isCancelled)
        }
        remoteHostWork.keep(task, on: host, token: token)
        return task
    }

    private func isCurrentRemoteHostRefresh(_ token: RemoteHostWork.Token, on host: String) -> Bool {
        !isTearingDownWorkspace && remoteHostList.hosts.contains(host) && !isDisconnected(host)
            && remoteHostWork.isCurrent(token, on: host)
    }

    private func applyRemoteRefreshConversations(
        _ conversations: [Conversation], host: String, token: RemoteHostWork.Token, step: RemoteSessionCopyStep? = nil
    ) {
        guard isCurrentRemoteHostRefresh(token, on: host) else { return }
        if let step { applyRemoteHostConversations(conversations, of: step, host: host) }
        else { applyRemoteHostConversations(conversations, host: host) }
    }

    private func finishRemoteHostRefresh(
        _ host: String, token: RemoteHostWork.Token, status: RemoteHostStatus?, discovery: RemoteSessionDiscovery
    ) {
        guard isCurrentRemoteHostRefresh(token, on: host) else { return }
        if let status {
            setTmuxSessionNames(status.tmuxSessionNames, on: .ssh(host))
            setTmuxServerProblem(status.tmuxServerProblem, on: host)
            if let locations = status.cliLocations {
                RemoteHostCLILocations.shared.setLocations(locations, on: host)
                setInstalledProviders(Set(locations.keys), on: .ssh(host))
            }
            checkClaudeSessionIDFlagIfUnanswered(on: host)
        }
        let refreshedAt = Date.now
        setRemoteHostRefreshStatus(.refreshed(refreshedAt), host: host)
        noteLoginState(on: host, refreshProblem: nil)
        shareRemoteHostCopy(host, refreshedAt: refreshedAt, status: status, discovery: discovery)
        if let status { checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: status.installedProviders != nil) }
    }

    private func failRemoteHostRefresh(_ host: String, token: RemoteHostWork.Token, error: any Error) {
        guard isCurrentRemoteHostRefresh(token, on: host) else { return }
        setRemoteHostRefreshStatus(.failed(error.localizedDescription), host: host)
        if case .sshFailed(_, let problem)? = error as? RemoteSessionMirrorError {
            noteLoginState(on: host, refreshProblem: problem)
            if problem == .windowsHost { return }
        }
        checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: false)
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

    /// Lists a disconnected host's sessions from its last copy, as at launch, without reaching the host; see
    /// `ConversationStore+RemoteHostDisconnect`. Its refresh status stays as it was, since nothing was refreshed.
    func listRemoteHostFromMirror(_ host: String) {
        guard !isTearingDownWorkspace, remoteHostList.hosts.contains(host), hostRefreshStatuses[.ssh(host)] != .refreshing,
              let token = remoteHostWork.beginRead(on: host) else { return }
        let discovery = remoteSessionDiscovery
        let coordinator = windowRegistry.hostSessionWork
        let configuredHosts = Array(Set(storesOfEveryWindow.flatMap { $0.remoteHostList.hosts }))
        Task.detached(priority: .userInitiated) { [weak self] in
            try? await coordinator.withAccess(to: [.ssh(host)]) { [weak self] in
                discovery.mirror.migrateLegacyMirrors(for: configuredHosts)
                guard let mirroredConversations = try? discovery.readMirror(host: host) else { return }
                await self?.applyRemoteMirrorListing(mirroredConversations, host: host, token: token)
            }
        }
    }

    private func applyRemoteMirrorListing(_ conversations: [Conversation], host: String, token: RemoteHostWork.Token) {
        guard !isTearingDownWorkspace, remoteHostList.hosts.contains(host), remoteHostWork.isCurrentRead(token, on: host) else { return }
        applyRemoteHostConversations(conversations, host: host, discardMissingReopeningTabs: false)
    }

    /// Why the app can't log in to `host` without a prompt, or through a login made with Connect…, or nil when it
    /// can; checked before the host is added, also when it couldn't be reached a moment ago.
    func connectionProblem(
        on host: String,
        check: RemoteHostConnectionCheck = RemoteHostConnectionCheck()
    ) async -> SSHConnectionProblem? {
        SSHHostReachability.shared.forget(host)
        return await Task.detached(priority: .userInitiated) { check.problem(connectingTo: host) }.value
    }

    /// Where `ssh` would connect for the host, and the listed host that connects to the same place, read off the main
    /// actor with `ssh -G`.
    func sameMachineCheck(for host: String) async -> SSHHostSameMachineCheck {
        let listedHosts = remoteHostList.hosts
        return await Task.detached(priority: .userInitiated) {
            SSHHostSameMachineCheck.check(host: host, listedHosts: listedHosts)
        }.value
    }

    /// Returns false when the host is not a valid `ssh` destination or is already listed.
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
        // A Try Again that waited for this host's refresh can start for the other hosts' sessions; the refresh
        // ends without reporting, now that the host is gone.
        resumeQueuedHostWorkInAllWindows()
    }

    private func canRemoveRemoteMirror(_ host: String, generation: UInt64) -> Bool {
        !remoteHostList.hosts.contains(host) && remoteHostWork.lifecycle(on: host) == generation
    }

    /// Lists a host's sessions from its copy, and links the tabs waiting for them.
    func applyRemoteHostConversations(
        _ hostConversations: [Conversation],
        host: String,
        discardMissingReopeningTabs: Bool = true
    ) {
        // The host may have been removed while its copy ran.
        guard remoteHostList.hosts.contains(host) else { return }
        replaceConversations(on: .ssh(host), with: hostConversations, discardMissingReopeningTabs: discardMissingReopeningTabs)
        linkWaitingTabsToPreassignedSessions(on: .ssh(host))
        linkWaitingTabsByAppearance(on: .ssh(host))
    }

    /// Lists one tool's sessions as soon as they are copied, in place of that tool's earlier ones; the host's other
    /// tools keep theirs until their own copy. A copy that lists the same sessions as before changes nothing, so the
    /// whole list isn't sorted, compared, and shown again for it: each of the 6 tools' steps did that on every
    /// refresh, 5–24 ms apiece with 3,365 sessions listed (PERF-88). A tab waiting to reopen is given up only once
    /// every tool is listed, since its session may be one of a tool not copied yet.
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

    /// Whether the list has the tool's sessions on the host as `copied` has them, in any order: one pass over the
    /// list, and no second array of it.
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

    private func setRemoteSessionCopyStep(_ step: RemoteSessionCopyStep, host: String, token: RemoteHostWork.Token) {
        guard isCurrentRemoteHostRefresh(token, on: host) else { return }
        remoteSessionCopySteps[.ssh(host)] = step
    }

    private func setRemoteHostRefreshStatus(_ status: HostRefreshStatus, host: String) {
        guard remoteHostList.hosts.contains(host) else { return }
        hostRefreshStatuses[.ssh(host)] = status
        if case .failed = status {
            remoteHostCopies.noteEnd(of: host, failed: true)
        } else {
            remoteHostCopies.noteEnd(of: host, failed: false)
        }
        remoteSessionCopySteps.removeValue(forKey: .ssh(host))
        // A Try Again that waited for this refresh can start now.
        resumeQueuedHostWorkInAllWindows()
    }
}
