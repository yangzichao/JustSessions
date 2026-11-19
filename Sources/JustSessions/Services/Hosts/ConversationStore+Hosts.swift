import Foundation

extension ConversationStore {
    var hosts: [SessionHost] {
        [.thisMac] + remoteHostList.hosts.map(SessionHost.ssh)
    }

    var hasRemoteHosts: Bool { !remoteHostList.hosts.isEmpty }

    var isScanningThisMac: Bool { hostRefreshStatuses[.thisMac] == .refreshing }

    func refresh(_ host: SessionHost) {
        switch host {
        case .thisMac: refreshThisMac()
        case .ssh(let destination) where isDisconnected(destination): listRemoteHostFromMirror(destination)
        case .ssh(let destination): refreshRemoteHost(destination)
        }
    }

    func refreshTryingAgain(_ host: SessionHost) {
        guard !isDisconnected(host) else {
            connectIfDisconnected(host)
            return
        }
        if let destination = host.sshDestination { SSHHostReachability.shared.forget(destination) }
        refresh(host)
    }

    func launchNewSession(
        provider: ConversationProvider,
        host: SessionHost,
        folder: String,
        creatingMissingFolder: Bool = false,
        deletesSessionWhenClosed: Bool = false,
        resolver: RemoteFolderResolver = RemoteFolderResolver()
    ) async throws {
        let location = try await projectLocation(
            of: folder,
            on: host,
            creatingMissingFolder: creatingMissingFolder,
            resolver: resolver
        )
        try launchNewSession(provider: provider, in: location, deletesSessionWhenClosed: deletesSessionWhenClosed)
    }

    func projectLocation(
        of folder: String,
        on host: SessionHost,
        creatingMissingFolder: Bool = false,
        resolver: RemoteFolderResolver
    ) async throws -> ProjectLocation {
        switch host {
        case .thisMac:
            let path = try ThisMacFolderResolver.resolvedPath(of: folder, creatingMissingFolder: creatingMissingFolder)
            return ProjectLocation(host: .thisMac, path: path)
        case .ssh(let destination):
            connectIfDisconnected(host)
            let resolvedPath = try await Task.detached(priority: .userInitiated) {
                try resolver.resolvedPath(of: folder, host: destination, creatingMissingFolder: creatingMissingFolder)
            }.value
            return ProjectLocation(host: host, path: resolvedPath)
        }
    }
}
