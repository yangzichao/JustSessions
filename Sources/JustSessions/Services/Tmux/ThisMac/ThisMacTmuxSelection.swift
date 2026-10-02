import Foundation

/// The background refresh chooses a compatible server; opening a tab reads that choice without spawning probes.
final class ThisMacTmuxSelection: @unchecked Sendable {
    private let lock = NSLock()
    private var selectedServer: ThisMacTmuxServer?

    var server: ThisMacTmuxServer? {
        lock.withLock { selectedServer }
    }

    func select(from candidates: [ThisMacTmuxServer]) -> ThisMacTmuxServer? {
        let supportedServers = candidates.filter { $0.hasSupportedVersion() }
        // An installed version may already own running work. Keep its client until that server exits,
        // since tmux versions can use incompatible client/server protocols. Never kill it to migrate.
        let selected = supportedServers.first(where: { $0.hasRunningSessions }) ?? supportedServers.first
        lock.withLock { selectedServer = selected }
        return selected
    }
}
