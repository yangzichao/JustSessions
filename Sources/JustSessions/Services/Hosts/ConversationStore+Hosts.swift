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

    func refresh(_ host: SessionHost) {
        switch host {
        case .thisMac: refreshThisMac()
        case .ssh(let destination): refreshRemoteHost(destination)
        }
    }

    /// From the New Session sheet. A folder typed for an SSH host is looked up there first, so a missing folder is
    /// reported before a tab opens, and the tab waits under the path the CLI records for its session.
    func launchNewSession(
        provider: ConversationProvider,
        host: SessionHost,
        folder: String,
        resolver: RemoteFolderResolver = RemoteFolderResolver()
    ) async throws {
        try launchNewSession(provider: provider, in: try await projectLocation(of: folder, on: host, resolver: resolver))
    }

    /// A folder typed in the New Session sheet. On an SSH host it is looked up there, which fails when it is missing.
    func projectLocation(of folder: String, on host: SessionHost, resolver: RemoteFolderResolver) async throws -> ProjectLocation {
        switch host {
        case .thisMac:
            return ProjectLocation(host: .thisMac, path: folder)
        case .ssh(let destination):
            let resolvedPath = try await Task.detached(priority: .userInitiated) {
                try resolver.resolvedPath(of: folder, host: destination)
            }.value
            return ProjectLocation(host: host, path: resolvedPath)
        }
    }
}
