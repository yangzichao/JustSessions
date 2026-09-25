import Foundation

/// Sessions on SSH hosts. Each host is copied into a local mirror in the background, apart from the local
/// `refresh()`, so a slow or unreachable host never holds up the local list.
extension ConversationStore {
    var isSyncingRemoteHosts: Bool {
        remoteHostSyncStatuses.values.contains(.syncing)
    }

    var hasRemoteHostFailure: Bool {
        remoteHostSyncStatuses.values.contains(where: \.isFailure)
    }

    /// Local sessions and every remote host; what the refresh button and app launch run.
    func refreshIncludingRemoteHosts() {
        refresh()
        refreshRemoteHosts()
    }

    func refreshRemoteHosts() {
        for host in remoteHostList.hosts { refreshRemoteHost(host) }
    }

    func refreshRemoteHost(_ host: String, discovery: RemoteSessionDiscovery = RemoteSessionDiscovery()) {
        guard remoteHostList.hosts.contains(host), remoteHostSyncStatuses[host] != .syncing else { return }
        remoteHostSyncStatuses[host] = .syncing
        Task.detached(priority: .userInitiated) {
            // The last copy lists right away; the host may be slow or offline.
            if let mirroredConversations = try? discovery.readMirror(host: host), !mirroredConversations.isEmpty {
                await self.applyRemoteHostConversations(mirroredConversations, host: host)
            }
            do {
                let hostConversations = try discovery.discover(host: host)
                await self.applyRemoteHostConversations(hostConversations, host: host)
                await self.setRemoteHostSyncStatus(.synced(.now), host: host)
            } catch {
                await self.setRemoteHostSyncStatus(.failed(error.localizedDescription), host: host)
            }
        }
    }

    /// Returns false when the host is not a valid `ssh` destination or is already listed.
    @discardableResult
    func addRemoteHost(_ proposedHost: String) -> Bool {
        guard remoteHostList.add(proposedHost), let host = RemoteHostList.normalizedHost(proposedHost) else { return false }
        remoteHostList.save(to: .standard)
        refreshRemoteHost(host)
        return true
    }

    func removeRemoteHost(_ host: String, mirror: RemoteSessionMirror = RemoteSessionMirror()) {
        remoteHostList.remove(host)
        remoteHostList.save(to: .standard)
        remoteHostSyncStatuses.removeValue(forKey: host)
        replaceConversations(onRemoteHost: host, with: [])
        Task.detached(priority: .utility) { mirror.removeMirror(host: host) }
    }

    private func applyRemoteHostConversations(_ hostConversations: [Conversation], host: String) {
        // The host may have been removed while its copy ran.
        guard remoteHostList.hosts.contains(host) else { return }
        replaceConversations(onRemoteHost: host, with: hostConversations)
    }

    private func setRemoteHostSyncStatus(_ status: RemoteHostSyncStatus, host: String) {
        guard remoteHostList.hosts.contains(host) else { return }
        remoteHostSyncStatuses[host] = status
    }
}
