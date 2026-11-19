import Foundation

final class ThisMacTmuxSelection: @unchecked Sendable {
    private let lock = NSLock()
    private var selectedServer: ThisMacTmuxServer?
    private var latestGeneration = 0

    var server: ThisMacTmuxServer? {
        lock.withLock { selectedServer }
    }

    func beginProbeGeneration() -> Int {
        lock.withLock {
            latestGeneration &+= 1
            return latestGeneration
        }
    }

    func probe(from candidates: [ThisMacTmuxServer]) -> ThisMacTmuxServer? {
        let supportedServers = candidates.filter { $0.hasSupportedVersion() }
        // An installed version may already own running work. Keep its client until that server exits,
        // since tmux versions can use incompatible client/server protocols. Never kill it to migrate.
        return supportedServers.first(where: { $0.hasRunningSessions }) ?? supportedServers.first
    }

    @discardableResult
    func commit(_ server: ThisMacTmuxServer?, generation: Int) -> ThisMacTmuxServer? {
        lock.withLock {
            guard generation == latestGeneration else { return selectedServer }
            selectedServer = server
            return server
        }
    }

    func select(from candidates: [ThisMacTmuxServer]) -> ThisMacTmuxServer? {
        let generation = beginProbeGeneration()
        return commit(probe(from: candidates), generation: generation)
    }
}
