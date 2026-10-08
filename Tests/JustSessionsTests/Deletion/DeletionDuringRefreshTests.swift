import Foundation
import Testing
@testable import JustSessions

/// A refresh that read a host before one of its sessions was deleted would list that session again, so deleting
/// from a host and refreshing it never overlap.
@MainActor
struct DeletionDuringRefreshTests {
    @Test func aSessionWaitsForItsOwnHostsRefreshOnly() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let local = try sandbox.savedConversation()
        let remote = Conversation.fixture(host: .ssh("devbox"))
        let store = sandbox.makeStore(listing: [local])
        store.replaceConversations(on: .ssh("devbox"), with: [remote])
        store.hostRefreshStatuses[.ssh("devbox")] = .refreshing

        store.deleteConversations([remote])
        #expect(!store.isDeletingSessions)
        #expect(store.queuedDeletionConversationIDs == [remote.id])

        store.deleteConversations([local])
        #expect(store.pendingDeletionConversationIDs == [local.id])
        try await expectEventually { !store.isDeletingSessions }

        // The deletion's end did not start the session still waiting for devbox's refresh.
        #expect(!sandbox.fileExists(for: local))
        #expect(store.queuedDeletionConversationIDs == [remote.id])
        #expect(store.conversations.map(\.id) == [remote.id])
    }

    @Test func aRefreshAskedForDuringADeletionRunsOnceItEnds() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let deleted = try sandbox.savedConversation()
        let kept = try sandbox.savedConversation()
        let store = sandbox.makeStore(listing: [deleted, kept])

        store.delete(deleted)
        store.refreshThisMac()
        #expect(store.hostRefreshStatuses[.thisMac] == nil)

        try await expectEventually { !store.isDeletingSessions }
        try await expectEventually {
            if case .refreshed = store.hostRefreshStatuses[.thisMac] { return true }
            return false
        }
        #expect(store.conversations.map(\.id) == [kept.id])
        #expect(!sandbox.fileExists(for: deleted))
    }
}
