import Foundation
import Testing

@testable import JustSessions

@MainActor
struct ArchivedSessionsTests {
    @Test func archivingAndUnarchivingChangesOnlyTheSessionsNamed() {
        var archived = ArchivedSessions()
        archived.setArchived(true, conversationIDs: ["first", "second", "third"])
        archived.setArchived(false, conversationIDs: ["second", "never-archived"])

        #expect(archived.archivedConversationIDs == ["first", "third"])
        #expect(archived.isArchived(conversationID: "first"))
        #expect(!archived.isArchived(conversationID: "second"))
    }

    @Test func theArchiveOutlivesARestart() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let archivedConversation = Conversation.fixture(title: "Done with this")
        let otherConversation = Conversation.fixture(title: "Still going")
        let store = makeStore(listing: [archivedConversation, otherConversation], userDefaults: isolatedUserDefaults.userDefaults)

        store.setArchived(true, conversations: [archivedConversation])

        let relaunchedStore = makeStore(
            listing: [archivedConversation, otherConversation], userDefaults: isolatedUserDefaults.userDefaults)
        #expect(relaunchedStore.archivedSessions.archivedConversationIDs == [archivedConversation.id])
        relaunchedStore.setArchived(false, conversations: [archivedConversation])
        #expect(ArchivedSessions.load(from: isolatedUserDefaults.userDefaults).archivedConversationIDs.isEmpty)
    }

    @Test func archivingHidesTheSessionUntilShowArchivedIsOnAndKeepsItsPinAndName() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let archivedConversation = Conversation.fixture(provider: .claude, title: "Archive me")
        let olderArchived = Conversation.fixture(
            provider: .claude, title: "Old archived", updatedAt: .now.addingTimeInterval(-30 * 24 * 3_600)
        )
        let codexConversation = Conversation.fixture(provider: .codex, title: "Keep me")
        let store = makeStore(
            listing: [archivedConversation, olderArchived, codexConversation],
            userDefaults: isolatedUserDefaults.userDefaults
        )
        store.setPinned(true, conversation: archivedConversation)
        store.rename(archivedConversation, to: "Custom name")
        _ = store.filteredSidebarProjection(providerFilter: .all, recencyFilter: .all, searchText: "")

        store.setArchived(true, conversations: [archivedConversation, olderArchived])

        let hidden = store.filteredSidebarProjection(providerFilter: .all, recencyFilter: .all, searchText: "")
        #expect(hidden.projects.flatMap { $0.conversations.map(\.id) } == [codexConversation.id])
        #expect(hidden.listedConversationIDs == [codexConversation.id])
        #expect(hidden.allSessionCount == 1)
        #expect(hidden.recentSessionCount == 1)
        #expect(hidden.archivedSessionCount == 2)

        let shown = store.filteredSidebarProjection(
            providerFilter: .all, recencyFilter: .all, archiveFilter: .showArchived, searchText: ""
        )
        #expect(
            shown.projects.flatMap { $0.conversations.map(\.id) }
                == [archivedConversation.id, codexConversation.id, olderArchived.id])
        #expect(shown.allSessionCount == 3)
        #expect(shown.recentSessionCount == 2)
        #expect(store.pinnedItems.isPinned(conversationID: archivedConversation.id))
        #expect(store.title(for: archivedConversation) == "Custom name")

        let codexOnly = store.filteredSidebarProjection(providerFilter: .only(.codex), recencyFilter: .all, searchText: "")
        #expect(codexOnly.archivedSessionCount == 0)
    }

    @Test func searchFindsArchivedSessionsOnlyWhileShowArchivedIsOn() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let archivedConversation = Conversation.fixture(title: "Archived refactor")
        let store = makeStore(listing: [archivedConversation], userDefaults: isolatedUserDefaults.userDefaults)
        store.setArchived(true, conversations: [archivedConversation])

        let hidden = store.filteredSidebarProjection(providerFilter: .all, recencyFilter: .all, searchText: "refactor")
        #expect(hidden.projects.flatMap(\.conversations).isEmpty)
        let shown = store.filteredSidebarProjection(
            providerFilter: .all, recencyFilter: .all, archiveFilter: .showArchived, searchText: "refactor"
        )
        #expect(shown.projects.flatMap { $0.conversations.map(\.id) } == [archivedConversation.id])
    }

    private func makeStore(listing conversations: [Conversation], userDefaults: UserDefaults) -> ConversationStore {
        let store = ConversationStore(
            adapters: [],
            userDefaults: userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            startsBackgroundPolling: false
        )
        store.replaceConversations(on: .thisMac, with: conversations)
        return store
    }
}
