import Foundation

@testable import JustSessions

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

final class ClaudeHostStandIn: Sendable {
    enum Failure: Sendable {
        case copy
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
                    let reading = readings.appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(at: readings, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: claudeFolder, to: reading)
                    refreshes.noteRead()
                    if failure == .copy {
                        throw RemoteSessionMirrorError.rsyncFailed(host: host, output: "Connection reset by peer")
                    }
                    if holds { refreshes.waitWhileHeld() }
                    Self.noteOutOfReach(host)
                    refreshes.noteStatusLookupFailure()
                    var folders = RemoteToolFolders.standard
                    folders.claude = reading.path
                    return folders
                }
            ))
    }

    var refreshesThatReadTheHost: Int { refreshes.count }
    var refreshesThatFailedWithoutConnecting: Int { refreshes.failuresWithoutConnecting }

    func holdNextRefresh() { refreshes.holdNext() }
    func releaseHeldRefresh() { refreshes.release() }
    func failNextRefreshes(_ count: Int = 1, as failure: Failure = .copy) { refreshes.failNext(count, as: failure) }

    func forgetStatusLookupFailure() {
        if refreshes.takeStatusLookupFailure() { SSHHostReachability.shared.forget(host) }
    }

    func remove() {
        refreshes.release()
        SSHHostReachability.shared.forget(host)
    }

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

final class StandInClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date.now

    var now: Date { lock.withLock { current } }

    func advance(by interval: TimeInterval) { lock.withLock { current += interval } }
}
