import Foundation
import Testing
@testable import JustSessions

@MainActor
@Suite(.serialized, .oneHeldThreadAtATime)
struct RemoteRefreshLifecycleTests {
    @Test func disconnectCancelsAnExistingRefreshBeforeAnotherToolOrStatusStarts() async throws {
        let sandbox = try TwoWindowSandbox(remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }))
        defer { sandbox.tearDown() }
        let store = sandbox.first
        store.remoteHostList = RemoteHostList(hosts: ["devbox"])
        let previous = Conversation.fixture(host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [previous])
        let completedAt = Date.now - 60
        store.hostRefreshStatuses[.ssh("devbox")] = .refreshed(completedAt)
        store.tmuxSessionNamesByHost[.ssh("devbox")] = [TmuxSessionName.forConversation(previous)]
        let pause = PausedRemoteFolders()
        defer { pause.release() }
        let probes = RemoteRefreshProbeCount()
        let home = sandbox.root.appendingPathComponent("home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let mirror = RemoteSessionMirror(cacheRoot: sandbox.root.appendingPathComponent("cache"), sourceHomeOverride: home.path,
                                         toolFoldersLookup: { _ in pause.read() })
        let task = try #require(store.refreshRemoteHost("devbox", discovery: RemoteSessionDiscovery(mirror: mirror, status: { _ in probes.read() })))
        try await expectEventually { pause.isWaiting }

        store.disconnectHost("devbox", endingTmuxSessions: false, connections: SSHLoginConnections(close: { _, _ in }))
        pause.release()
        await task.value

        #expect(task.isCancelled)
        #expect(probes.count == 0)
        #expect(store.isDisconnected("devbox"))
        #expect(store.hostRefreshStatuses[.ssh("devbox")] == .refreshed(completedAt))
        #expect(store.conversations.filter { $0.host == .ssh("devbox") }.map(\.id) == [previous.id])
        #expect(store.tmuxSessionNamesByHost[.ssh("devbox"), default: []].isEmpty)
        #expect(store.remoteSessionCopySteps[.ssh("devbox")] == nil)
        #expect(!FileManager.default.fileExists(atPath: mirror.mirrorDirectory(host: "devbox", provider: .claude).path))
    }

    @Test func removingAndAddingAHostRejectsOldWorkAndKeepsTheNewCopy() async throws {
        let sandbox = try TwoWindowSandbox(remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }))
        defer { sandbox.tearDown() }
        let store = sandbox.first
        for window in [sandbox.first, sandbox.second] { window.remoteHostList = RemoteHostList(hosts: ["devbox"]) }
        let oldGeneration = sandbox.second.hostLifecycleGeneration(on: .ssh("devbox"))
        let pause = PausedRemoteFolders()
        defer { pause.release() }
        let probes = RemoteRefreshProbeCount()
        let home = sandbox.root.appendingPathComponent("home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let cache = sandbox.root.appendingPathComponent("cache")
        let oldMirror = RemoteSessionMirror(cacheRoot: cache, sourceHomeOverride: home.path, toolFoldersLookup: { _ in pause.read() })
        let task = try #require(store.refreshRemoteHost("devbox", discovery: RemoteSessionDiscovery(mirror: oldMirror, status: { _ in probes.read() })))
        try await expectEventually { pause.isWaiting }

        store.removeRemoteHost("devbox", mirror: oldMirror)
        #expect(!sandbox.second.isCurrentHostLifecycle(oldGeneration, on: .ssh("devbox")))
        let id = UUID().uuidString.lowercased()
        let project = home.appendingPathComponent(".claude/projects/-srv-new")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try #"{"type":"user","cwd":"/srv/new","message":{"content":"New copy"}}"#.appending("\n")
            .write(to: project.appendingPathComponent("\(id).jsonl"), atomically: true, encoding: .utf8)
        let mirror = RemoteSessionMirror(cacheRoot: cache, sourceHomeOverride: home.path)
        store.remoteSessionDiscovery = RemoteSessionDiscovery(mirror: mirror, status: { _ in RemoteHostStatus(tmuxSessionNames: [], cliLocations: [:]) })
        #expect(store.addRemoteHost("devbox"))
        pause.release()
        await task.value
        try await expectEventually { store.conversations.contains { $0.sessionID == id } && store.hostRefreshStatuses[.ssh("devbox")] != .refreshing }

        #expect(probes.count == 0)
        let copied = store.conversations.filter { $0.host == .ssh("devbox") }
        #expect(copied.map(\.sessionID) == [id])
        #expect(FileManager.default.fileExists(atPath: try #require(copied.first).sourceFile.path))
    }

    @Test func listingTokensRejectOldLifecyclesAndOutOfOrderCopies() {
        let work = RemoteHostWork()
        let first = work.beginRead(on: "devbox", copiedAt: Date(timeIntervalSinceReferenceDate: 10))!
        let second = work.beginRead(on: "devbox", copiedAt: Date(timeIntervalSinceReferenceDate: 20))!
        #expect(!work.isCurrentRead(first, on: "devbox"))
        #expect(work.isCurrentRead(second, on: "devbox"))
        #expect(work.beginRead(on: "devbox", copiedAt: Date(timeIntervalSinceReferenceDate: 15)) == nil)
        work.invalidate("devbox")
        #expect(!work.isCurrentRead(second, on: "devbox"))
    }

    @Test func disconnectDiscardsAnotherWindowsQueuedDeletionBeforeLateRefreshCompletion() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let registry = WorkspaceWindowRegistry()
        let recorder = RemoteCommandRecorder()
        let conversation = Conversation.fixture(sourceFile: root.appendingPathComponent("old.jsonl"), host: .ssh("devbox"))
        func makeStore() -> ConversationStore {
            let store = ConversationStore(adapters: [StaticConversationAdapter(discoveredConversations: [])],
                                          userDefaults: settings.userDefaults, windowRegistry: registry,
                                          remoteDeletion: RemoteConversationDeletion(runner: recorder.runner(answering: (0, ""))),
                                          remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }), startsBackgroundPolling: false)
            store.remoteHostList = RemoteHostList(hosts: ["devbox"])
            store.replaceConversations(on: .ssh("devbox"), with: [conversation])
            return store
        }
        let first = makeStore(), second = makeStore()
        let pause = PausedRemoteFolders()
        defer { pause.release() }
        let home = root.appendingPathComponent("home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let mirror = RemoteSessionMirror(cacheRoot: root.appendingPathComponent("cache"), sourceHomeOverride: home.path, toolFoldersLookup: { _ in pause.read() })
        let task = try #require(first.refreshRemoteHost("devbox", discovery: RemoteSessionDiscovery(mirror: mirror, status: { _ in nil })))
        try await expectEventually { pause.isWaiting }
        second.deleteConversations([conversation])
        #expect(second.queuedDeletionConversationIDs == [conversation.id])

        first.disconnectHost("devbox", endingTmuxSessions: false, connections: SSHLoginConnections(close: { _, _ in }))
        pause.release()
        await task.value
        try await Task.sleep(for: .milliseconds(50))

        #expect(first.isDisconnected("devbox") && second.isDisconnected("devbox"))
        #expect(second.queuedDeletionConversationIDs.isEmpty)
        #expect(!second.isDeletingSessions)
        #expect(recorder.commands.isEmpty)
        #expect(first.hostRefreshStatuses[.ssh("devbox")] != .refreshing)
        #expect(second.hostRefreshStatuses[.ssh("devbox")] != .refreshing)
    }
}

private final class PausedRemoteFolders: @unchecked Sendable {
    private let lock = NSLock()
    private let ready = DispatchSemaphore(value: 0)
    private var waiting = false
    var isWaiting: Bool { lock.withLock { waiting } }
    func read() -> RemoteToolFolders {
        lock.withLock { waiting = true }
        _ = ready.wait(timeout: .now() + 10)
        return .standard
    }
    func release() { ready.signal() }
}

private final class RemoteRefreshProbeCount: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.withLock { value } }
    func read() -> RemoteHostStatus? {
        lock.withLock { value += 1 }
        return RemoteHostStatus(tmuxSessionNames: ["justsessions-claude-stale"], cliLocations: [:])
    }
}
