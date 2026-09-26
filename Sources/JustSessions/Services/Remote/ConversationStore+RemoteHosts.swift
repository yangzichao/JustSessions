import Foundation

/// Sessions on SSH hosts. Each host is copied into a local mirror in the background, apart from this Mac's scan,
/// so a slow or unreachable host never holds up the rest of the list.
extension ConversationStore {
    func refreshRemoteHost(_ host: String, discovery: RemoteSessionDiscovery = RemoteSessionDiscovery()) {
        guard remoteHostList.hosts.contains(host), hostRefreshStatuses[.ssh(host)] != .refreshing else { return }
        hostRefreshStatuses[.ssh(host)] = .refreshing
        Task.detached(priority: .userInitiated) {
            // The last copy lists right away; the host may be slow or offline.
            if let mirroredConversations = try? discovery.readMirror(host: host), !mirroredConversations.isEmpty {
                await self.applyRemoteHostConversations(mirroredConversations, host: host)
            }
            do {
                let hostConversations = try discovery.discover(host: host)
                await self.applyRemoteHostConversations(hostConversations, host: host)
                if let tmuxSessionNames = Self.listRemoteTmuxSessions(host: host) {
                    await self.setTmuxSessionNames(tmuxSessionNames, on: .ssh(host))
                }
                await self.setRemoteHostRefreshStatus(.refreshed(.now), host: host)
            } catch {
                await self.setRemoteHostRefreshStatus(.failed(error.localizedDescription), host: host)
            }
        }
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
        hostRefreshStatuses.removeValue(forKey: .ssh(host))
        tmuxSessionNamesByHost.removeValue(forKey: .ssh(host))
        replaceConversations(on: .ssh(host), with: [])
        Task.detached(priority: .utility) { mirror.removeMirror(host: host) }
    }

    private func applyRemoteHostConversations(_ hostConversations: [Conversation], host: String) {
        // The host may have been removed while its copy ran.
        guard remoteHostList.hosts.contains(host) else { return }
        replaceConversations(on: .ssh(host), with: hostConversations)
        linkWaitingRemoteNewSessionTabs(onHost: host)
    }

    private func setRemoteHostRefreshStatus(_ status: HostRefreshStatus, host: String) {
        guard remoteHostList.hosts.contains(host) else { return }
        hostRefreshStatuses[.ssh(host)] = status
    }
}
