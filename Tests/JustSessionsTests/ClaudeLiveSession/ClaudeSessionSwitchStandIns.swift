import Foundation

@testable import JustSessions

/// Claude Code's adapter over a test's folder, counting this Mac's scans. Its next scan can be held once it has read
/// the folder, as a scan in flight is while the CLI writes a session it didn't see.
final class HoldableClaudeScans: ConversationAdapter, @unchecked Sendable {
    let provider = ConversationProvider.claude
    private let adapter: ClaudeAdapter
    private let lock = NSLock()
    private var scans = 0
    private var holdsNextScan = false
    private var isHolding = false

    init(configurationDirectory: URL) {
        adapter = ClaudeAdapter(configurationDirectory: configurationDirectory)
    }

    /// Scans that have read the folder.
    var scanCount: Int { lock.withLock { scans } }

    func holdNextScan() { lock.withLock { holdsNextScan = true } }
    func releaseHeldScan() { lock.withLock { isHolding = false } }

    func discover(cancellation: ConversationDiscoveryCancellation) throws -> [Conversation] {
        let found = try adapter.discover(cancellation: cancellation)
        lock.withLock {
            scans += 1
            isHolding = holdsNextScan
            holdsNextScan = false
        }
        let deadline = Date.now.addingTimeInterval(120)
        while lock.withLock({ isHolding }), !cancellation.isCancelled, Date.now < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        return found
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] {
        adapter.arguments(for: conversation, action: action)
    }

    func delete(_ conversation: Conversation) throws {}
}

/// Stands in for an SSH host whose home is `home`. Each refresh copies the host's Claude Code folder with `rsync` as it
/// is when the refresh reads it, so a refresh lists a session only when it read the host after the session was written.
/// The next refresh can be held once it has read the host, as one under way is, or the next ones fail: their copy, or
/// their connection, as when the host is out of reach, which `SSHHostReachability` then remembers. While it does, a
/// refresh fails at once without connecting, through the same lookup and runner as a real host's. `ssh` is never run:
/// the status lookup after a copy finds the made-up host out of reach too, which `forgetStatusLookupFailure()` undoes.
final class ClaudeHostStandIn: Sendable {
    enum Failure: Sendable {
        /// The host was reached, and its copy failed.
        case copy
        /// `ssh` couldn't reach the host.
        case outOfReach
    }

    static let outOfReachOutput = "ssh: Could not resolve hostname: nodename nor servname provided, or not known"

    let host = "claude-follow-\(UUID().uuidString.prefix(8).lowercased()).invalid"
    let discovery: RemoteSessionDiscovery
    private let refreshes = Refreshes()

    init(home: URL, in directory: URL) throws {
        let readings = directory.appendingPathComponent("host-readings-\(UUID().uuidString)")
        let otherToolsHome = directory.appendingPathComponent("other-tools-home")
        try FileManager.default.createDirectory(at: otherToolsHome, withIntermediateDirectories: true)
        let claudeFolder = home.appendingPathComponent(RemoteSessionMirror.remoteFolder(for: .claude))
        let refreshes = refreshes
        discovery = RemoteSessionDiscovery(
            mirror: RemoteSessionMirror(
                cacheRoot: directory.appendingPathComponent("mirrors"),
                hostAccess: .standIn(home: otherToolsHome.path),
                toolFoldersLookup: { host in
                    if SSHHostReachability.shared.recentFailureOutput(on: host) != nil {
                        refreshes.noteFailureWithoutConnecting()
                        return try RemoteToolFoldersLookup.folders(on: host, runner: RemoteHostCommandRunner())
                    }
                    let (holds, failure) = refreshes.start()
                    if failure == .outOfReach {
                        Self.noteOutOfReach(host)
                        throw RemoteSessionMirrorError.sshFailed(
                            host: host, problem: SSHConnectionProblem(sshOutput: Self.outOfReachOutput)
                        )
                    }
                    // What the host has as this refresh reads it, which the refresh copies. It counts as having read the
                    // host only once that is done, so a test that waits for it writes nothing this refresh could see.
                    let reading = readings.appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(at: readings, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: claudeFolder, to: reading)
                    refreshes.noteRead()
                    if failure == .copy {
                        throw RemoteSessionMirrorError.rsyncFailed(host: host, output: "Connection reset by peer")
                    }
                    if holds { refreshes.waitWhileHeld() }
                    // So the status lookup after the copy doesn't run `ssh`.
                    Self.noteOutOfReach(host)
                    refreshes.noteStatusLookupFailure()
                    var folders = RemoteToolFolders.standard
                    folders.claude = reading.path
                    return folders
                }
            ))
    }

    /// Refreshes that have read the host.
    var refreshesThatReadTheHost: Int { refreshes.count }
    /// Refreshes that failed at once, without connecting, while the host was remembered out of reach.
    var refreshesThatFailedWithoutConnecting: Int { refreshes.failuresWithoutConnecting }

    func holdNextRefresh() { refreshes.holdNext() }
    func releaseHeldRefresh() { refreshes.release() }
    func failNextRefreshes(_ count: Int = 1, as failure: Failure = .copy) { refreshes.failNext(count, as: failure) }

    /// Once a refresh that read the host ends: a real host that was copied answers the status lookup after the copy,
    /// so nothing would remember it out of reach. A host that couldn't be reached stays remembered.
    func forgetStatusLookupFailure() {
        if refreshes.takeStatusLookupFailure() { SSHHostReachability.shared.forget(host) }
    }

    func remove() {
        refreshes.release()
        SSHHostReachability.shared.forget(host)
    }

    /// What a background command records once `ssh` couldn't reach the host.
    private static func noteOutOfReach(_ host: String) {
        SSHHostReachability.shared.noteResult(
            exitStatus: RemoteHostCommandRunner.connectionFailureExitStatus,
            output: outOfReachOutput,
            on: host
        )
    }

    private final class Refreshes: @unchecked Sendable {
        private let lock = NSLock()
        private var read = 0
        private var withoutConnecting = 0
        private var holdsNext = false
        private var isHolding = false
        private var failuresToCome = 0
        private var nextFailure = Failure.copy
        private var leftStatusLookupFailure = false

        var count: Int { lock.withLock { read } }
        var failuresWithoutConnecting: Int { lock.withLock { withoutConnecting } }

        func holdNext() { lock.withLock { holdsNext = true } }
        func release() { lock.withLock { isHolding = false } }

        func failNext(_ count: Int, as failure: Failure) {
            lock.withLock {
                failuresToCome = count
                nextFailure = failure
            }
        }

        func start() -> (holds: Bool, failure: Failure?) {
            lock.withLock {
                let next = (holdsNext, failuresToCome > 0 ? nextFailure : nil)
                isHolding = holdsNext
                holdsNext = false
                failuresToCome = max(failuresToCome - 1, 0)
                return next
            }
        }

        func noteRead() { lock.withLock { read += 1 } }
        func noteFailureWithoutConnecting() { lock.withLock { withoutConnecting += 1 } }
        func noteStatusLookupFailure() { lock.withLock { leftStatusLookupFailure = true } }

        func takeStatusLookupFailure() -> Bool {
            lock.withLock {
                defer { leftStatusLookupFailure = false }
                return leftStatusLookupFailure
            }
        }

        func waitWhileHeld() {
            let deadline = Date.now.addingTimeInterval(120)
            while lock.withLock({ isHolding }), Date.now < deadline { Thread.sleep(forTimeInterval: 0.01) }
        }
    }
}

/// A time that moves only when a test moves it.
final class StandInClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date.now

    var now: Date { lock.withLock { current } }

    func advance(by interval: TimeInterval) { lock.withLock { current += interval } }
}
