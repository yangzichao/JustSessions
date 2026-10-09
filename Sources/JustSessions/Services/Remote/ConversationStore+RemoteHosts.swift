import Foundation

/// Sessions on SSH hosts. Each host is copied into a local mirror in the background, apart from this Mac's scan,
/// so a slow or unreachable host never holds up the rest of the list.
extension ConversationStore {
    func refreshRemoteHost(_ host: String, discovery: RemoteSessionDiscovery = RemoteSessionDiscovery()) {
        guard remoteHostList.hosts.contains(host),
              !deferRefreshWhileDeleting(on: .ssh(host)),
              hostRefreshStatuses[.ssh(host)] != .refreshing else { return }
        hostRefreshStatuses[.ssh(host)] = .refreshing
        Task.detached(priority: .userInitiated) {
            // The last copy lists right away; the host may be slow or offline.
            if let mirroredConversations = try? discovery.readMirror(host: host), !mirroredConversations.isEmpty {
                await self.applyRemoteHostConversations(mirroredConversations, host: host)
            }
            do {
                let hostConversations = try discovery.discover(host: host)
                await self.applyRemoteHostConversations(hostConversations, host: host)
                let status = RemoteHostStatusProbe.status(ofHost: host)
                if let status {
                    await self.setTmuxSessionNames(status.tmuxSessionNames, on: .ssh(host))
                    if let installedProviders = status.installedProviders {
                        await self.setInstalledProviders(installedProviders, on: .ssh(host))
                    }
                    await self.checkClaudeSessionIDFlagIfUnanswered(on: host)
                }
                await self.setRemoteHostRefreshStatus(.refreshed(.now), host: host)
                // After the refresh, so a check that changes how the host's shell starts can refresh it again.
                if let status {
                    await self.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: status.installedProviders != nil)
                }
            } catch {
                await self.setRemoteHostRefreshStatus(.failed(error.localizedDescription), host: host)
                await self.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: false)
            }
        }
    }

    /// Why the app can't log in to `host` without a prompt, or nil when it can; checked before the host is added.
    func connectionProblem(
        on host: String,
        check: RemoteHostConnectionCheck = RemoteHostConnectionCheck()
    ) async -> SSHConnectionProblem? {
        await Task.detached(priority: .userInitiated) { check.problem(connectingTo: host) }.value
    }

    /// Returns false when the host is not a valid `ssh` destination or is already listed.
    @discardableResult
    func addRemoteHost(_ proposedHost: String) -> Bool {
        guard remoteHostList.add(proposedHost), let host = RemoteHostList.normalizedHost(proposedHost) else { return false }
        remoteHostList.save(to: userDefaults)
        refreshRemoteHost(host)
        return true
    }

    func removeRemoteHost(_ host: String, mirror: RemoteSessionMirror = RemoteSessionMirror()) {
        remoteHostList.remove(host)
        remoteHostList.save(to: userDefaults)
        remoteHostsUsingTmuxPrefix.setUsesTmuxPrefix(false, for: host)
        remoteHostsUsingTmuxPrefix.save(to: userDefaults)
        forgetRemoteShellStartup(on: host)
        hostRefreshStatuses.removeValue(forKey: .ssh(host))
        tmuxSessionNamesByHost.removeValue(forKey: .ssh(host))
        installedProvidersByHost.removeValue(forKey: .ssh(host))
        replaceConversations(on: .ssh(host), with: [])
        Task.detached(priority: .utility) { mirror.removeMirror(host: host) }
        // A Try Again that waited for this host's refresh can start for the other hosts' sessions; the refresh
        // ends without reporting, now that the host is gone.
        startQueuedDeletion()
    }

    /// Lists a host's sessions from its copy, and links the tabs waiting for them.
    func applyRemoteHostConversations(_ hostConversations: [Conversation], host: String) {
        // The host may have been removed while its copy ran.
        guard remoteHostList.hosts.contains(host) else { return }
        replaceConversations(on: .ssh(host), with: hostConversations)
        linkWaitingTabsToPreassignedSessions(on: .ssh(host))
        linkWaitingTabsByAppearance(on: .ssh(host))
    }

    private func setRemoteHostRefreshStatus(_ status: HostRefreshStatus, host: String) {
        guard remoteHostList.hosts.contains(host) else { return }
        hostRefreshStatuses[.ssh(host)] = status
        // A Try Again that waited for this refresh can start now.
        startQueuedDeletion()
    }
}
