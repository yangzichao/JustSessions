import Foundation
import Testing
@testable import JustSessions

/// Windows refreshing an SSH host at once, as Connect has them do, copy it once: the windows whose refresh was asked
/// for before the copy started list it, or show its failure, instead of copying the host again (PERF-26).
@MainActor
@Suite(.oneHeldThreadAtATime)
struct RefreshingInSeveralWindowsTests {
    @Test func connectingInTwoWindowsCopiesTheHostOnce() async throws {
        let sandbox = try TwoWindowSandbox(remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }))
        defer { sandbox.tearDown() }
        let copies = HostCopyGate()
        let sessionID = try Self.listDisconnectedHost(in: sandbox, copies: copies)

        sandbox.second.connectHost("devbox")

        for store in [sandbox.first, sandbox.second] { #expect(store.hostRefreshStatuses[.ssh("devbox")] == .refreshing) }
        try await expectEventually { [sandbox.first, sandbox.second].allSatisfy(\.hasRefreshedDevbox) }
        #expect(copies.count == 1)
        #expect(sandbox.first.hostRefreshStatuses[.ssh("devbox")] == sandbox.second.hostRefreshStatuses[.ssh("devbox")])
        for store in [sandbox.first, sandbox.second] {
            #expect(store.conversations.filter { $0.host == .ssh("devbox") }.map(\.sessionID) == [sessionID])
            #expect(store.tmuxSessionNamesByHost[.ssh("devbox")] == ["justsessions-claude-1"])
        }
    }

    /// The host may have changed since the copy started.
    @Test func aRefreshAskedForWhileAnotherWindowCopiesCopiesAgainAfterIt() async throws {
        let sandbox = try TwoWindowSandbox(remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }))
        defer { sandbox.tearDown() }
        let copies = HostCopyGate(pausesUntilReleased: true)
        defer { copies.release() }
        _ = try Self.listDisconnectedHost(in: sandbox, copies: copies, disconnected: false)

        sandbox.first.refreshRemoteHost("devbox")
        try await expectEventually { copies.count == 1 }
        sandbox.second.refreshRemoteHost("devbox")
        copies.release()

        try await expectEventually { [sandbox.first, sandbox.second].allSatisfy(\.hasRefreshedDevbox) }
        #expect(copies.count == 2)
    }

    @Test func anotherWindowsFailedCopyStandsForTheRefreshesWaitingForIt() async throws {
        let sandbox = try TwoWindowSandbox(remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }))
        defer { sandbox.tearDown() }
        let copies = HostCopyGate(failure: RemoteSessionMirrorError.sshFailed(host: "devbox", problem: .noAnswer))
        _ = try Self.listDisconnectedHost(in: sandbox, copies: copies)

        sandbox.second.connectHost("devbox")

        try await expectEventually {
            [sandbox.first, sandbox.second].allSatisfy { store in
                if case .failed? = store.hostRefreshStatuses[.ssh("devbox")] { true } else { false }
            }
        }
        #expect(copies.count == 1)
        #expect(sandbox.first.hostRefreshStatuses[.ssh("devbox")] == sandbox.second.hostRefreshStatuses[.ssh("devbox")])
    }

    /// The copying window's refresh no longer counts, as when its window closes, so its copy stands for nothing.
    @Test func aCanceledCopyLeavesTheWaitingRefreshToCopy() async throws {
        let sandbox = try TwoWindowSandbox(remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }))
        defer { sandbox.tearDown() }
        let firstWindowCopies = HostCopyGate(pausesUntilReleased: true)
        let secondWindowCopies = HostCopyGate(pausesUntilReleased: true)
        defer { firstWindowCopies.release(); secondWindowCopies.release() }
        _ = try Self.listDisconnectedHost(in: sandbox, copies: firstWindowCopies, secondWindowCopies: secondWindowCopies)

        sandbox.second.connectHost("devbox")
        try await expectEventually { firstWindowCopies.count + secondWindowCopies.count == 1 }
        let (copyingStore, waitingStore, waitingWindowCopies) = firstWindowCopies.count == 1
            ? (sandbox.first, sandbox.second, secondWindowCopies)
            : (sandbox.second, sandbox.first, firstWindowCopies)
        copyingStore.invalidateRemoteHostWork(on: "devbox")
        firstWindowCopies.release()
        secondWindowCopies.release()

        try await expectEventually { waitingStore.hasRefreshedDevbox }
        #expect(waitingWindowCopies.count == 1)
    }

    /// Both windows list `devbox`, disconnected unless told otherwise, whose home holds one Claude Code session. Its
    /// copies go through `copies`, or the second window's through `secondWindowCopies`. Returns the session's ID.
    private static func listDisconnectedHost(
        in sandbox: TwoWindowSandbox,
        copies: HostCopyGate,
        secondWindowCopies: HostCopyGate? = nil,
        disconnected: Bool = true
    ) throws -> String {
        let home = sandbox.root.appendingPathComponent("devbox-home")
        let project = home.appendingPathComponent(".claude/projects/-srv-app")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let sessionID = UUID().uuidString.lowercased()
        try #"{"type":"user","cwd":"/srv/app","message":{"content":"Fix the build"}}"#
            .appending("\n")
            .write(to: project.appendingPathComponent("\(sessionID).jsonl"), atomically: true, encoding: .utf8)
        let discovery = { (gate: HostCopyGate) in
            RemoteSessionDiscovery(
                mirror: RemoteSessionMirror(
                    cacheRoot: sandbox.root.appendingPathComponent("cache"),
                    sourceHomeOverride: home.path,
                    toolFoldersLookup: { _ in try gate.startCopy() }
                ),
                status: { _ in RemoteHostStatus(tmuxSessionNames: ["justsessions-claude-1"], cliLocations: [:]) }
            )
        }
        for (store, gate) in [(sandbox.first, copies), (sandbox.second, secondWindowCopies ?? copies)] {
            store.remoteHostList = RemoteHostList(hosts: ["devbox"])
            store.remoteSessionDiscovery = discovery(gate)
            if disconnected { store.disconnectedRemoteHosts.setDisconnected(true, for: "devbox") }
        }
        return sessionID
    }
}

private extension ConversationStore {
    var hasRefreshedDevbox: Bool {
        if case .refreshed? = hostRefreshStatuses[.ssh("devbox")] { true } else { false }
    }
}

/// Counts the copies of the host, as each starts by looking up its tools' folders; can hold them until released, or
/// fail them.
private final class HostCopyGate: @unchecked Sendable {
    private let lock = NSLock()
    private let opened = DispatchSemaphore(value: 0)
    private var copyCount = 0
    private var isOpen: Bool
    private let failure: (any Error)?

    init(pausesUntilReleased: Bool = false, failure: (any Error)? = nil) {
        isOpen = !pausesUntilReleased
        self.failure = failure
    }

    var count: Int { lock.withLock { copyCount } }

    func startCopy() throws -> RemoteToolFolders {
        let mustWait = lock.withLock {
            copyCount += 1
            return !isOpen
        }
        if mustWait {
            // Only the test opens the gate; parallel UI tests can delay its main-actor turn beyond a timeout.
            opened.wait()
            opened.signal()
        }
        if let failure { throw failure }
        return .standard
    }

    /// Lets every held copy, and the later ones, go on.
    func release() {
        let wasOpen = lock.withLock {
            defer { isOpen = true }
            return isOpen
        }
        if !wasOpen { opened.signal() }
    }
}
