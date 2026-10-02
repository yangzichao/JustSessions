import Foundation
import Testing
@testable import JustSessions

/// A session already gone, for example deleted just before a dropped connection hid the result, counts as deleted.
@MainActor
struct AlreadyGoneSessionDeletionTests {
    @Test func aSessionAlreadyGoneFromAnSSHHostLeavesTheListWithoutAnError() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let gone = try sandbox.savedConversation(onHost: "devbox", updatedAt: .now)
        let deleted = try sandbox.savedConversation(onHost: "devbox", updatedAt: Date.now.addingTimeInterval(-60))
        let hosts = SimulatedSSHHosts { _, attempt in attempt == 1 ? SimulatedSSHHosts.alreadyGone : SimulatedSSHHosts.deleted }
        let store = sandbox.makeStore(listing: [gone, deleted], remoteDeletion: hosts.deletion)

        store.deleteConversations([gone, deleted])
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.conversations.isEmpty)
        #expect(store.alert == nil)
        #expect(!sandbox.fileExists(for: gone))
    }

    @Test func aSessionAlreadyGoneFromThisMacLeavesTheListWithoutAnError() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let gone = try sandbox.savedConversation(title: "Gone")
        let store = sandbox.makeStore(listing: [gone], adapters: [AlreadyGoneAdapter()])

        store.delete(gone)
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.conversations.isEmpty)
        #expect(store.alert == nil)
    }

    /// Reports every session as no longer present, as the real adapters do for a file that is gone.
    private struct AlreadyGoneAdapter: ConversationAdapter {
        let provider = ConversationProvider.claude
        func discover() throws -> [Conversation] { [] }
        func arguments(for conversation: Conversation, action: ConversationAction) -> [String] { [] }
        func delete(_ conversation: Conversation) throws { throw ConversationDeletionError.missingSource }
    }
}
