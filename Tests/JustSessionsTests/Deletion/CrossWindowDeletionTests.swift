import Foundation
import Testing
@testable import JustSessions

@Suite(.serialized, .oneHeldThreadAtATime)
@MainActor
struct CrossWindowDeletionTests {
    @Test func anotherWindowsDeleteAndRefreshWaitForTheRunningDeletion() async throws {
        let fixture = try CrossWindowDeletionFixture(blocksDiscovery: false)
        defer { fixture.remove() }
        let firstSession = fixture.conversations[0]
        let secondSession = fixture.conversations[1]
        fixture.first.delete(firstSession)
        try await expectEventually { fixture.adapter.deleteCalls == 1 }
        fixture.second.delete(secondSession)
        fixture.second.refreshThisMac()
        #expect(fixture.second.queuedDeletionConversationIDs == [secondSession.id])
        #expect(fixture.second.hostRefreshStatuses[.thisMac] == nil)
        fixture.adapter.release()
        try await expectEventually {
            fixture.adapter.deleteCalls == 2 && !fixture.second.isDeletingSessions && !fixture.second.isScanningThisMac
                && fixture.second.queuedDeletionConversationIDs.isEmpty
        }
        #expect(!fixture.adapter.overlapped)
        #expect(fixture.first.conversations.isEmpty)
        #expect(fixture.second.conversations.isEmpty)
    }

    @Test func anotherWindowsDeletionWaitsForTheRefreshToPublish() async throws {
        let fixture = try CrossWindowDeletionFixture(blocksDiscovery: true)
        defer { fixture.remove() }
        fixture.first.refreshThisMac()
        try await expectEventually { fixture.adapter.discoveryCalls == 1 }
        fixture.second.delete(fixture.conversations[0])
        #expect(fixture.adapter.deleteCalls == 0)
        #expect(fixture.second.queuedDeletionConversationIDs == [fixture.conversations[0].id])
        fixture.adapter.release()
        try await expectEventually { fixture.adapter.deleteCalls == 1 && !fixture.second.isDeletingSessions }
        #expect(!fixture.adapter.overlapped)
        #expect(fixture.first.conversations.map(\.id) == [fixture.conversations[1].id])
        #expect(fixture.second.conversations.map(\.id) == [fixture.conversations[1].id])
    }

    @Test func closingTheScanningWindowDoesNotReleaseItsStillRunningDiskWork() async throws {
        let fixture = try CrossWindowDeletionFixture(blocksDiscovery: true)
        defer { fixture.remove() }
        fixture.first.refreshThisMac()
        try await expectEventually { fixture.adapter.discoveryCalls == 1 }
        fixture.second.delete(fixture.conversations[0])
        #expect(fixture.second.queuedDeletionConversationIDs == [fixture.conversations[0].id])
        fixture.first.closeWorkspace()
        // The window is gone and its waiter canceled, but the producer still holds the host's reservation.
        try await Task.sleep(for: .milliseconds(100))
        #expect(fixture.adapter.deleteCalls == 0)
        fixture.adapter.release()
        try await expectEventually { fixture.adapter.deleteCalls == 1 && !fixture.second.isDeletingSessions }
        #expect(!fixture.adapter.overlapped)
    }

    @Test func aClosedWindowsDeletionStaysPendingAndDisconnectStopsItsRemainingSessions() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let conversations = try [sandbox.savedConversation(onHost: "devbox"),
                                 sandbox.savedConversation(onHost: "devbox", updatedAt: .now - 60)]
        let registry = WorkspaceWindowRegistry()
        let deletion = PausedRemoteDeletion()
        defer { deletion.release() }
        func makeStore() -> ConversationStore {
            let store = ConversationStore(
                adapters: [StaticConversationAdapter(discoveredConversations: [])],
                userDefaults: sandbox.userDefaults, windowRegistry: registry,
                remoteDeletion: RemoteConversationDeletion(runner: RemoteHostCommandRunner { _, _, _ in deletion.run() }),
                remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }), startsBackgroundPolling: false
            )
            store.remoteHostList = RemoteHostList(hosts: ["devbox"])
            store.replaceConversations(on: .ssh("devbox"), with: conversations)
            return store
        }
        let first = makeStore(), second = makeStore()
        defer { first.closeWorkspace(); second.closeWorkspace() }
        first.deleteConversations(conversations)
        try await expectEventually { deletion.calls == 1 }
        first.closeWorkspace()

        #expect(registry.stores.count == 1)
        #expect(second.isDeletionPending(for: conversations[1]))
        #expect(second.isDeleting(on: .ssh("devbox")))
        second.disconnectHost("devbox", endingTmuxSessions: false, connections: SSHLoginConnections(close: { _, _ in }))
        deletion.release()
        try await expectEventually { !first.isDeletingSessions }

        #expect(deletion.calls == 1)
        #expect(second.isDisconnected("devbox"))
        #expect(second.terminalSessions.isEmpty)
        #expect(second.conversations.filter { $0.host == .ssh("devbox") }.map(\.id) == [conversations[1].id])
        #expect(!second.isDeletionPending(for: conversations[1]))
        #expect(registry.storesWithSessionWork.count == 1)
    }
}

private final class PausedRemoteDeletion: @unchecked Sendable {
    private let lock = NSLock()
    private let gate = DispatchSemaphore(value: 0)
    private var count = 0
    var calls: Int { lock.withLock { count } }
    func run() -> (exitStatus: Int32, output: String) {
        let call = lock.withLock { count += 1; return count }
        if call == 1 { _ = gate.wait(timeout: .now() + 30) }
        return (0, "")
    }
    func release() { gate.signal() }
}

@MainActor
private struct CrossWindowDeletionFixture {
    let sandbox: DeletionSandbox
    let conversations: [Conversation]
    let adapter: CoordinatedDeletionAdapter
    let first: ConversationStore
    let second: ConversationStore

    init(blocksDiscovery: Bool) throws {
        sandbox = try DeletionSandbox()
        conversations = try [sandbox.savedConversation(), sandbox.savedConversation()]
        adapter = CoordinatedDeletionAdapter(conversations: conversations, blocksDiscovery: blocksDiscovery)
        let registry = WorkspaceWindowRegistry()
        let resolver = NativeCLICommandResolver(searchDirectories: [], inheritedEnvironment: [:], bundledTmuxDirectory: nil)
        let adapter = adapter
        let sandbox = sandbox
        let makeStore = {
            ConversationStore(adapters: [adapter], commandResolver: resolver, userDefaults: sandbox.userDefaults,
                              windowRegistry: registry, startsBackgroundPolling: false)
        }
        first = makeStore()
        second = makeStore()
        for store in [first, second] { store.replaceConversations(on: .thisMac, with: conversations) }
    }

    func remove() {
        adapter.release()
        first.closeWorkspace()
        second.closeWorkspace()
        sandbox.remove()
    }
}

private final class CoordinatedDeletionAdapter: ConversationAdapter, @unchecked Sendable {
    let provider = ConversationProvider.claude
    private let conversations: [Conversation]
    private let blocksDiscovery: Bool
    private let gate = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var discoveries = 0
    private var deletions = 0
    private var active = 0
    private var overlap = false
    var discoveryCalls: Int { lock.withLock { discoveries } }
    var deleteCalls: Int { lock.withLock { deletions } }
    var overlapped: Bool { lock.withLock { overlap } }

    init(conversations: [Conversation], blocksDiscovery: Bool) {
        self.conversations = conversations
        self.blocksDiscovery = blocksDiscovery
    }

    func discover(cancellation: ConversationDiscoveryCancellation) throws -> [Conversation] {
        let count = enter(deleting: false)
        defer { leave() }
        if blocksDiscovery && count == 1 { _ = gate.wait(timeout: .now() + 30) }
        try cancellation.checkCancellation()
        return conversations.filter { FileManager.default.fileExists(atPath: $0.sourceFile.path) }
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] { [] }

    func delete(_ conversation: Conversation) throws {
        let count = enter(deleting: true)
        defer { leave() }
        if !blocksDiscovery && count == 1 { _ = gate.wait(timeout: .now() + 30) }
        try FileManager.default.removeItem(at: conversation.sourceFile)
    }

    func release() { gate.signal() }
    private func enter(deleting: Bool) -> Int {
        lock.withLock {
            active += 1
            overlap = overlap || active > 1
            if deleting { deletions += 1; return deletions }
            discoveries += 1
            return discoveries
        }
    }
    private func leave() { lock.withLock { active -= 1 } }
}
