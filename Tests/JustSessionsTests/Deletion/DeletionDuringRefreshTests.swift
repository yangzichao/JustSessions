import Foundation
import Testing
@testable import JustSessions

/// A refresh that read a host before one of its sessions was deleted would list that session again, so deleting
/// from a host and refreshing it never overlap.
@MainActor
struct DeletionDuringRefreshTests {
    @Test func aSessionWaitsForItsOwnHostsRefreshOnly() throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let local = try sandbox.savedConversation()
        let remote = Conversation.fixture(host: .ssh("devbox"))
        let store = sandbox.makeStore(listing: [local])
        store.replaceConversations(on: .ssh("devbox"), with: [remote])

        store.hostRefreshStatuses[.ssh("devbox")] = .refreshing
        #expect(!store.canStartDeletion(of: [remote]))
        #expect(!store.canStartDeletion(of: [local, remote]))
        #expect(store.canStartDeletion(of: [local]))

        store.hostRefreshStatuses[.ssh("devbox")] = .refreshed(.now)
        store.hostRefreshStatuses[.thisMac] = .refreshing
        #expect(store.canStartDeletion(of: [remote]))
        #expect(!store.canStartDeletion(of: [local]))
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
