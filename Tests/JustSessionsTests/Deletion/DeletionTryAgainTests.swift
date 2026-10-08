import Foundation
import Testing
@testable import JustSessions

/// Try Again in the alert after a deletion lost its connection to a host.
@MainActor
struct DeletionTryAgainTests {
    @Test func tryAgainDeletesExactlyTheFailedSessionsStillListedAndDeletable() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        // Newest first, the order deletion goes in.
        let onDevbox = try (0..<6).map {
            try sandbox.savedConversation(onHost: "devbox", title: "Remote \($0)", updatedAt: Date.now.addingTimeInterval(-Double($0) * 60))
        }
        let refused = try sandbox.savedConversation(title: "Locked", updatedAt: Date.now.addingTimeInterval(-3_600))
        let refusingAdapter = FileBackedConversationAdapter(
            provider: .claude,
            conversations: [refused],
            refusedSessionIDs: [refused.sessionID],
            refusalReason: "Permission denied"
        )
        // The third deletion on devbox loses the connection; later ones go through.
        let hosts = SimulatedSSHHosts { _, attempt in attempt == 3 ? SimulatedSSHHosts.connectionLost : SimulatedSSHHosts.deleted }
        let store = sandbox.makeStore(listing: onDevbox + [refused], adapters: [refusingAdapter], remoteDeletion: hosts.deletion)

        store.deleteConversations(onDevbox + [refused])
        try await expectEventually { !store.isDeletingSessions }
        let alert = try #require(store.alert)
        #expect(alert.title == "5 sessions weren't deleted")
        #expect(alert.retryConversationIDs == Set(onDevbox.dropFirst(2).map(\.id)))
        #expect(hosts.attempts(on: "devbox") == 3)

        // Meanwhile one of them was opened, so it can't be deleted now.
        store.tmuxSessionNamesByHost[.ssh("devbox")] = [TmuxSessionName.forConversation(onDevbox[5])]
        store.dismissError()
        store.retryDeletion(of: alert.retryConversationIDs)
        #expect(store.pendingDeletionConversationIDs == Set(onDevbox[2...4].map(\.id)))
        try await expectEventually { !store.isDeletingSessions }

        #expect(hosts.attempts(on: "devbox") == 6)
        #expect(store.conversations.map(\.id) == [onDevbox[5].id, refused.id])
        #expect(store.alert == nil)
    }

    /// The alert can appear while a scan of this Mac starts, as when one waited for the deletion. Try Again on
    /// sessions on this Mac then waits for the scan.
    @Test func tryAgainDuringAScanOfThisMacRunsWhenTheScanEnds() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let session = try sandbox.savedConversation(title: "Refactor")
        let store = sandbox.makeStore(listing: [session])

        store.refreshThisMac()
        #expect(store.isScanningThisMac)
        store.retryDeletion(of: [session.id])
        #expect(!store.isDeletingSessions)
        #expect(store.queuedDeletionConversationIDs == [session.id])
        try await expectEventually { !store.isScanningThisMac && !store.isDeletingSessions && store.conversations.isEmpty }

        #expect(!sandbox.fileExists(for: session))
        #expect(store.queuedDeletionConversationIDs.isEmpty)
        #expect(store.alert == nil)
    }

    /// The same after a deletion, whose waiting refresh of the host starts as the alert appears. Only a refresh
    /// of the host the sessions are on holds the retry up.
    @Test func tryAgainDuringARefreshOfTheSSHHostRunsWhenTheRefreshEnds() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let session = try sandbox.savedConversation(onHost: "devbox", title: "Refactor")
        let onBuildbox = try sandbox.savedConversation(onHost: "buildbox", title: "Elsewhere")
        // The first two tries lose the connection; the third deletes the session.
        let hosts = SimulatedSSHHosts { _, attempt in attempt <= 2 ? SimulatedSSHHosts.connectionLost : SimulatedSSHHosts.deleted }
        let store = sandbox.makeStore(listing: [session, onBuildbox], remoteDeletion: hosts.deletion)
        store.delete(session)
        try await expectEventually { !store.isDeletingSessions }
        let retryConversationIDs = try #require(store.alert?.retryConversationIDs)

        // A refresh of another host does not hold the retry up.
        store.refreshRemoteHost("buildbox", discovery: try Self.discoveryThatFailsWithoutSSH(in: sandbox))
        store.dismissError()
        store.retryDeletion(of: retryConversationIDs)
        #expect(store.isDeletingSessions)
        try await expectEventually { !store.isDeletingSessions && store.hostRefreshStatuses[.ssh("buildbox")] != .refreshing }
        #expect(hosts.attempts(on: "devbox") == 2)

        // A refresh of devbox does, until it ends.
        store.refreshRemoteHost("devbox", discovery: try Self.discoveryThatFailsWithoutSSH(in: sandbox))
        #expect(store.hostRefreshStatuses[.ssh("devbox")] == .refreshing)
        store.dismissError()
        store.retryDeletion(of: retryConversationIDs)
        #expect(!store.isDeletingSessions)
        #expect(store.queuedDeletionConversationIDs == [session.id])
        try await expectEventually { hosts.attempts(on: "devbox") == 3 && !store.isDeletingSessions }

        #expect(store.conversations.map(\.id) == [onBuildbox.id])
        #expect(store.queuedDeletionConversationIDs.isEmpty)
        #expect(store.alert == nil)
        // Started once: later refreshes find nothing waiting.
        store.refreshRemoteHost("devbox", discovery: try Self.discoveryThatFailsWithoutSSH(in: sandbox))
        try await expectEventually { store.hostRefreshStatuses[.ssh("devbox")] != .refreshing }
        #expect(hosts.attempts(on: "devbox") == 3)
    }

    /// Removing the host whose refresh held a retry up lets the retry of the other hosts' sessions start; that
    /// host's refresh then ends without reporting.
    @Test func tryAgainWaitingForAHostThatIsRemovedStartsAtOnce() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let onDevbox = try sandbox.savedConversation(onHost: "devbox", updatedAt: .now)
        let onBuildbox = try sandbox.savedConversation(onHost: "buildbox", updatedAt: Date.now.addingTimeInterval(-60))
        let hosts = SimulatedSSHHosts { _, attempt in attempt == 1 ? SimulatedSSHHosts.connectionLost : SimulatedSSHHosts.deleted }
        let store = sandbox.makeStore(listing: [onDevbox, onBuildbox], remoteDeletion: hosts.deletion)
        store.deleteConversations([onDevbox, onBuildbox])
        try await expectEventually { !store.isDeletingSessions }
        let retryConversationIDs = try #require(store.alert?.retryConversationIDs)
        #expect(retryConversationIDs == [onDevbox.id, onBuildbox.id])

        store.refreshRemoteHost("devbox", discovery: try Self.discoveryThatFailsWithoutSSH(in: sandbox))
        store.dismissError()
        store.retryDeletion(of: retryConversationIDs)
        #expect(!store.isDeletingSessions)
        store.removeRemoteHost("devbox", mirror: RemoteSessionMirror(cacheRoot: sandbox.directory.appendingPathComponent("mirrors")))

        #expect(store.pendingDeletionConversationIDs == [onBuildbox.id])
        #expect(store.queuedDeletionConversationIDs.isEmpty)
        try await expectEventually { !store.isDeletingSessions }
        #expect(hosts.attempts(on: "buildbox") == 2)
        #expect(store.conversations.isEmpty)
    }

    @Test func tryAgainDoesNothingWhenNoneOfTheSessionsIsStillListed() throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let store = sandbox.makeStore(listing: [try sandbox.savedConversation()])

        store.retryDeletion(of: ["gone"])

        #expect(!store.isDeletingSessions)
        #expect(store.conversations.count == 1)
    }

    @Test func tryAgainOfOneSessionReportsItAsOneSession() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let session = try sandbox.savedConversation(onHost: "devbox", title: "Refactor")
        let hosts = SimulatedSSHHosts { _, _ in SimulatedSSHHosts.connectionFailure }
        let store = sandbox.makeStore(listing: [session], remoteDeletion: hosts.deletion)

        store.delete(session)
        try await expectEventually { !store.isDeletingSessions }
        #expect(store.alert?.title == "Couldn't delete “Refactor”")
        #expect(store.alert?.message == "devbox couldn't be found. Check the host name and your network or VPN.")
        #expect(store.alert?.retryConversationIDs == [session.id])

        store.dismissError()
        store.retryDeletion(of: [session.id])
        try await expectEventually { !store.isDeletingSessions }
        #expect(hosts.attempts(on: "devbox") == 2)
        #expect(store.alert?.title == "Couldn't delete “Refactor”")
    }

    /// Its mirror would go inside a regular file, so the copy fails before any `rsync` or `ssh` runs.
    private static func discoveryThatFailsWithoutSSH(in sandbox: DeletionSandbox) throws -> RemoteSessionDiscovery {
        let notAFolder = sandbox.directory.appendingPathComponent("not-a-folder")
        if !FileManager.default.fileExists(atPath: notAFolder.path) {
            try "".write(to: notAFolder, atomically: true, encoding: .utf8)
        }
        return RemoteSessionDiscovery(mirror: RemoteSessionMirror(cacheRoot: notAFolder, sourceHomeOverride: sandbox.directory.path))
    }
}
