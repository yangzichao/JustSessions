import Foundation
import Testing

@testable import JustSessions

@MainActor
struct ConversationStoreDeletionTests {
    @Test func deletingASessionForgetsItsCustomTitlePinAndArchiving() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let deleted = try sandbox.savedConversation(title: "Deleted")
        let kept = try sandbox.savedConversation(title: "Kept")
        let store = sandbox.makeStore(listing: [deleted, kept])
        for conversation in [deleted, kept] {
            store.rename(conversation, to: "Custom \(conversation.suggestedTitle)")
            store.setPinned(true, conversation: conversation)
        }
        store.setArchived(true, conversations: [deleted, kept])

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
        #expect(ArchivedSessions.load(from: sandbox.userDefaults).archivedConversationIDs == [kept.id])
    }

    @Test func deletingASessionForgetsItsAndItsSubagentsBookmarks() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let deleted = try sandbox.savedConversation(.claude, title: "Deleted")
        let subagent = Conversation.fixture(provider: .claude, projectPath: deleted.projectPath, parentSessionID: deleted.sessionID)
        let kept = try sandbox.savedConversation(.claude, title: "Kept")
        let store = sandbox.makeStore(listing: [deleted, subagent, kept])
        for conversation in [deleted, subagent, kept] { store.toggleMessageBookmark(on: bookmarkableMessage, in: conversation) }

        store.delete(deleted)
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.conversations.map(\.id) == [kept.id])
        #expect(Set(MessageBookmarks.load(from: sandbox.userDefaults).bookmarksByConversationID.keys) == [kept.id])
        #expect(Set(store.messageBookmarks.bookmarksByConversationID.keys) == [kept.id])
        #expect(store.conversation(withID: subagent.id) == nil)
    }

    @Test func deletingAnAntigravitySessionKeepsItsSubagentsBookmarks() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let deleted = try sandbox.savedConversation(.antigravity, title: "Deleted")
        let subagent = Conversation.fixture(provider: .antigravity, projectPath: deleted.projectPath, parentSessionID: deleted.sessionID)
        let store = sandbox.makeStore(listing: [deleted, subagent])
        for conversation in [deleted, subagent] { store.toggleMessageBookmark(on: bookmarkableMessage, in: conversation) }

        store.delete(deleted)
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.conversations.isEmpty)
        #expect(Set(MessageBookmarks.load(from: sandbox.userDefaults).bookmarksByConversationID.keys) == [subagent.id])
        #expect(store.conversation(withID: subagent.id) != nil)
    }

    private var bookmarkableMessage: TranscriptEntry {
        TranscriptEntry(
            id: TranscriptPageIdentity.entryID(record: 2, part: 0), content: .userMessage("Keep this"),
            timestamp: nil, startsTurn: true)
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

        #expect(store.alert?.title == "Couldn't delete “Keep me”")
        #expect(store.errorMessage == "The session is locked.")
        #expect(store.alert?.offersTryAgain == false)
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

        #expect(store.alert?.title == "1 session wasn't deleted")
        #expect(
            store.errorMessage == "Deleted 1 of 2 sessions. The other one is still listed.\n\nClaude Code · Keep me: Permission denied.")
        #expect(store.conversations.map(\.id) == [refused.id])
    }

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

    @Test func aSessionGoneDespiteAnErrorKeepsItsCustomTitleInTheAlert() async throws {
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
        store.rename(conversation, to: "My refactor")

        store.delete(conversation)
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.alert?.title == "“My refactor” was deleted with an error")
        #expect(store.titleAliases.customTitlesByConversationID.isEmpty)
    }

    @Test func anOpenTerminalRefusalCutsALongTitle() throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let running = try sandbox.savedConversation(title: String(repeating: "Long title ", count: 12))
        let store = sandbox.makeStore(listing: [running])
        store.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(running)]

        store.delete(running)

        #expect(store.alert?.title == "Couldn't delete “Long title Long title Long title Long t…”")
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
        #expect(store.alert?.title == "Couldn't delete “Session”")
        #expect(sandbox.fileExists(for: running))
    }

    @Test func aSecondDeletionJoinsTheRunningOne() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let first = try sandbox.savedConversation()
        let second = try sandbox.savedConversation()
        let store = sandbox.makeStore(listing: [first, second])

        store.delete(first)
        store.delete(second)
        #expect(store.isDeletionPending(for: second))
        #expect(store.deletionProgress.totalCount == 2)
        store.deleteConversations([first, second])
        #expect(store.deletionProgress.totalCount == 2)
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.conversations.isEmpty)
        #expect(!sandbox.fileExists(for: first) && !sandbox.fileExists(for: second))
        #expect(store.alert == nil)
    }

    @Test func aDeletionWaitsWhileThisMacIsBeingScanned() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let conversation = try sandbox.savedConversation()
        let store = sandbox.makeStore(listing: [conversation])
        store.hostRefreshStatuses[.thisMac] = .refreshing

        store.delete(conversation)
        store.deleteConversations([conversation])

        #expect(!store.isDeletingSessions)
        #expect(store.queuedDeletionConversationIDs == [conversation.id])
        #expect(store.isDeletionPending(for: conversation))
        #expect(sandbox.fileExists(for: conversation))

        store.hostRefreshStatuses[.thisMac] = .refreshed(.now)
        store.startQueuedDeletion()
        try await expectEventually { !store.isDeletingSessions }
        #expect(store.queuedDeletionConversationIDs.isEmpty)
        #expect(!sandbox.fileExists(for: conversation))
    }
}
