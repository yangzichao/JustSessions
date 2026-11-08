import Foundation
import Testing
@testable import JustSessions

/// Once one window has copied an SSH host, the other windows list that copy instead of copying the host again.
@MainActor
struct SharedRemoteCopyTests {
    @Test func anotherWindowListsTheCopy() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let (discovery, sessionID) = try Self.copyWithOneClaudeSession(in: sandbox)
        let refreshedAt = Date.now
        let status = RemoteHostStatus(tmuxSessionNames: ["justsessions-claude-1"], cliLocations: [.claude: .loginShell])

        sandbox.first.shareRemoteHostCopy("devbox", refreshedAt: refreshedAt, status: status, discovery: discovery)

        try await expectEventually { sandbox.second.hostRefreshStatuses[.ssh("devbox")] == .refreshed(refreshedAt) }
        #expect(sandbox.second.conversations.filter { $0.host == .ssh("devbox") }.map(\.sessionID) == [sessionID])
        #expect(sandbox.second.tmuxSessionNamesByHost[.ssh("devbox")] == ["justsessions-claude-1"])
        #expect(sandbox.first.hostRefreshStatuses[.ssh("devbox")] == nil)
    }

    /// Its own refresh lists the host when it ends.
    @Test func aWindowRefreshingTheHostItselfIsLeftToItsRefresh() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let (discovery, _) = try Self.copyWithOneClaudeSession(in: sandbox)
        sandbox.second.hostRefreshStatuses[.ssh("devbox")] = .refreshing

        sandbox.first.shareRemoteHostCopy("devbox", refreshedAt: .now, status: nil, discovery: discovery)
        try await Task.sleep(for: .milliseconds(200))

        #expect(sandbox.second.hostRefreshStatuses[.ssh("devbox")] == .refreshing)
        #expect(!sandbox.second.conversations.contains { $0.host == .ssh("devbox") })
    }

    @Test func aDisconnectedWindowRejectsASharedCopyAndItsRunningMarks() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let (discovery, _) = try Self.copyWithOneClaudeSession(in: sandbox)
        sandbox.second.disconnectHost("devbox", endingTmuxSessions: false, connections: SSHLoginConnections(close: { _, _ in }))

        sandbox.first.shareRemoteHostCopy("devbox", refreshedAt: .now,
                                         status: RemoteHostStatus(tmuxSessionNames: ["justsessions-claude-stale"], cliLocations: [:]), discovery: discovery)
        try await Task.sleep(for: .milliseconds(50))

        #expect(sandbox.second.conversations.filter { $0.host == .ssh("devbox") }.isEmpty)
        #expect(sandbox.second.tmuxSessionNamesByHost[.ssh("devbox"), default: []].isEmpty)
        #expect(sandbox.second.hostRefreshStatuses[.ssh("devbox")] == nil)
    }

    @Test func aSharedCopyWaitsForHostMutationAndReadsItsCompletedResult() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let (discovery, _) = try Self.copyWithOneClaudeSession(in: sandbox)
        let source = try #require(discovery.readMirror(host: "devbox").first).sourceFile
        let pause = SharedCopyMutationPause()
        defer { pause.release() }
        let coordinator = sandbox.windowRegistry.hostSessionWork
        async let mutation: Void = coordinator.withAccess(to: [.ssh("devbox")]) { await pause.wait() }
        try await expectEventually { pause.isWaiting }
        let refreshedAt = Date.now

        sandbox.first.shareRemoteHostCopy("devbox", refreshedAt: refreshedAt, status: nil, discovery: discovery)
        try await Task.sleep(for: .milliseconds(100))
        #expect(sandbox.second.hostRefreshStatuses[.ssh("devbox")] == nil)
        #expect(sandbox.second.conversations.filter { $0.host == .ssh("devbox") }.isEmpty)

        try FileManager.default.removeItem(at: source)
        pause.release()
        try await mutation
        try await expectEventually { sandbox.second.hostRefreshStatuses[.ssh("devbox")] == .refreshed(refreshedAt) }
        #expect(sandbox.second.conversations.filter { $0.host == .ssh("devbox") }.isEmpty)
    }

    /// Both windows list `devbox`, whose copy holds one Claude Code session.
    private static func copyWithOneClaudeSession(in sandbox: TwoWindowSandbox) throws -> (RemoteSessionDiscovery, String) {
        for store in [sandbox.first, sandbox.second] { store.remoteHostList = RemoteHostList(hosts: ["devbox"]) }
        let mirror = RemoteSessionMirror(cacheRoot: sandbox.root.appendingPathComponent("cache"), sourceHomeOverride: sandbox.root.path)
        let project = mirror.mirrorDirectory(host: "devbox", provider: .claude).appendingPathComponent("projects/-srv-app")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let sessionID = UUID().uuidString.lowercased()
        try #"{"type":"user","cwd":"/srv/app","message":{"content":"Fix the build"}}"#
            .appending("\n")
            .write(to: project.appendingPathComponent("\(sessionID).jsonl"), atomically: true, encoding: .utf8)
        return (RemoteSessionDiscovery(mirror: mirror), sessionID)
    }
}

private final class SharedCopyMutationPause: @unchecked Sendable {
    private let lock = NSLock()
    private let gate: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private var waiting = false

    init() {
        let stream = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        gate = stream.stream
        continuation = stream.continuation
    }

    var isWaiting: Bool { lock.withLock { waiting } }
    func wait() async {
        lock.withLock { waiting = true }
        for await _ in gate { break }
    }
    func release() {
        continuation.yield(())
        continuation.finish()
    }
}
