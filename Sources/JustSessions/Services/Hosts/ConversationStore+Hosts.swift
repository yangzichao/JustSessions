import Foundation

/// This Mac and the SSH hosts are listed, refreshed, and started from alike. Only how a host's session files are
/// read and its CLI is reached differ; see `refreshThisMac()` and `ConversationStore+RemoteHosts`.
extension ConversationStore {
    /// This Mac first, then the SSH hosts in the order they were added.
    var hosts: [SessionHost] {
        [.thisMac] + remoteHostList.hosts.map(SessionHost.ssh)
    }

    var hasRemoteHosts: Bool { !remoteHostList.hosts.isEmpty }

    var isScanningThisMac: Bool { hostRefreshStatuses[.thisMac] == .refreshing }

    var isRefreshingAnyHost: Bool { hostRefreshStatuses.values.contains(.refreshing) }

    func refresh(_ host: SessionHost) {
        switch host {
        case .thisMac: refreshThisMac()
        case .ssh(let destination): refreshRemoteHost(destination)
        }
    }

    /// What the refresh button and app launch run.
    func refreshAllHosts() {
        for host in hosts { refresh(host) }
    }

    /// From the New Session sheet. A folder typed for an SSH host is looked up there first, so a missing folder is
    /// reported before a tab opens, and the tab waits under the path the CLI records for its session.
    func launchNewSession(
        provider: ConversationProvider,
        host: SessionHost,
        folder: String,
        resolver: RemoteFolderResolver = RemoteFolderResolver()
    ) async throws {
        switch host {
        case .thisMac:
            try launchNewSession(provider: provider, in: ProjectLocation(host: .thisMac, path: folder))
        case .ssh(let destination):
            let resolvedPath = try await Task.detached(priority: .userInitiated) {
                try resolver.resolvedPath(of: folder, host: destination)
            }.value
            try launchNewSession(provider: provider, in: ProjectLocation(host: host, path: resolvedPath))
        }
    }
}
