import Foundation
import Testing
@testable import JustSessions

/// Deleting from the store: what leaves the list, what stays, and what the user is told.
@MainActor
struct ConversationStoreDeletionTests {
    @Test func deletingASessionForgetsItsCustomTitleAndPin() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let deleted = try sandbox.savedConversation(title: "Deleted")
        let kept = try sandbox.savedConversation(title: "Kept")
        let store = sandbox.makeStore(listing: [deleted, kept])
        for conversation in [deleted, kept] {
            store.rename(conversation, to: "Custom \(conversation.suggestedTitle)")
            store.setPinned(true, conversation: conversation)
        }

        store.delete(deleted)
        #expect(store.isDeletionPending(for: deleted))
        #expect(!store.isDeletionPending(for: kept))
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.conversations.map(\.id) == [kept.id])
        #expect(!sandbox.fileExists(for: deleted))
        #expect(store.errorMessage == nil)
        let savedTitles = ConversationTitleAliases.load(from: sandbox.userDefaults)
        let savedPins = PinnedItems.load(from: sandbox.userDefaults)
        #expect(savedTitles.customTitlesByConversationID == [kept.id: "Custom Kept"])
        #expect(!savedPins.isPinned(conversationID: deleted.id))
        #expect(savedPins.isPinned(conversationID: kept.id))
    }

    @Test func aRefusedDeletionShowsTheToolsReasonAndKeepsTheSession() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let refused = try sandbox.savedConversation(.codex, title: "Keep me")
        let refusingAdapter = FileBackedConversationAdapter(
            provider: .codex,
            conversations: [refused],
            refusedSessionIDs: [refused.sessionID],
            refusalReason: "The session is locked."
        )
        let store = sandbox.makeStore(listing: [refused], adapters: [refusingAdapter])

        store.delete(refused)
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.errorMessage == "The session is locked.")
        #expect(store.conversations.map(\.id) == [refused.id])
        #expect(sandbox.fileExists(for: refused))
    }

    @Test func aBatchNamesEachSessionThatCouldNotBeDeleted() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let deleted = try sandbox.savedConversation(title: "Delete me")
        let refused = try sandbox.savedConversation(title: "Keep me")
        let refusingAdapter = FileBackedConversationAdapter(
            provider: .claude,
            conversations: [deleted, refused],
            refusedSessionIDs: [refused.sessionID],
            refusalReason: "Permission denied"
        )
        let store = sandbox.makeStore(listing: [deleted, refused], adapters: [refusingAdapter])

        store.deleteConversations([deleted, refused])
        #expect(store.isDeletionPending(for: deleted) && store.isDeletionPending(for: refused))
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.errorMessage == "Some sessions could not be deleted:\nClaude Code · Keep me: Permission denied")
        #expect(store.conversations.map(\.id) == [refused.id])
    }

    /// A tool can remove the file and then fail, say, to update its index. The session is gone either way.
    @Test func aSessionWhoseFileIsGoneLeavesTheListEvenWhenItsToolReportsAnError() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let conversation = try sandbox.savedConversation()
        let halfFailingAdapter = FileBackedConversationAdapter(
            provider: .claude,
            conversations: [conversation],
            refusedSessionIDs: [conversation.sessionID],
            refusalReason: "The index could not be updated.",
            removesRefusedFiles: true
        )
        let store = sandbox.makeStore(listing: [conversation], adapters: [halfFailingAdapter])

        store.delete(conversation)
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.conversations.isEmpty)
        #expect(store.errorMessage == "The index could not be updated.")
    }

    @Test func aSessionStillRunningInTmuxIsNotDeleted() throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let running = try sandbox.savedConversation()
        let store = sandbox.makeStore(listing: [running])
        store.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(running)]

        #expect(store.hasTerminal(for: running))
        #expect(store.deletionPlan(for: [running]).openTerminalCount == 1)
        store.delete(running)
        store.deleteConversations([running])

        #expect(!store.isDeletingSessions)
        #expect(store.errorMessage == ConversationDeletionError.activeTerminal.localizedDescription)
        #expect(sandbox.fileExists(for: running))
    }

    @Test func aSecondDeletionIsIgnoredWhileOneRuns() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let first = try sandbox.savedConversation()
        let second = try sandbox.savedConversation()
        let store = sandbox.makeStore(listing: [first, second])

        store.delete(first)
        store.delete(second)
        store.deleteConversations([second])
        #expect(!store.isDeletionPending(for: second))
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.conversations.map(\.id) == [second.id])
        #expect(sandbox.fileExists(for: second))
    }

    @Test func nothingIsDeletedWhileThisMacIsBeingScanned() throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let conversation = try sandbox.savedConversation()
        let store = sandbox.makeStore(listing: [conversation])
        store.hostRefreshStatuses[.thisMac] = .refreshing

        store.delete(conversation)
        store.deleteConversations([conversation])

        #expect(!store.isDeletingSessions)
        #expect(sandbox.fileExists(for: conversation))
    }

    @Test func antigravitySessionsAreNeverDeleted() throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let conversation = try sandbox.savedConversation(.antigravity)
        let store = sandbox.makeStore(listing: [conversation])

        store.delete(conversation)
        store.deleteConversations([conversation])

        #expect(!store.isDeletingSessions)
        #expect(store.errorMessage == nil)
        #expect(sandbox.fileExists(for: conversation))
    }
}
