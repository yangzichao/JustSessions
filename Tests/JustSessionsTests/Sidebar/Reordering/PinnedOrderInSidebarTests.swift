import Foundation
import Testing
@testable import JustSessions

/// Pinned projects and sessions stay in the order you put them, through activity and a relaunch.
@MainActor
struct PinnedOrderInSidebarTests {
    @Test func activityDoesNotReorderPinnedProjectsButADragDoes() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = makeStore(isolatedUserDefaults)
        let first = Conversation.fixture(projectPath: "/tmp/justsessions-tests/first", updatedAt: .now - 200)
        let second = Conversation.fixture(projectPath: "/tmp/justsessions-tests/second", updatedAt: .now - 100)
        let unpinned = Conversation.fixture(projectPath: "/tmp/justsessions-tests/unpinned", updatedAt: .now)
        store.replaceConversations(on: .thisMac, with: [first, second, unpinned])
        store.setPinned(true, projectPath: first.projectDirectoryKey)
        store.setPinned(true, projectPath: second.projectDirectoryKey)
        #expect(store.sidebarProjectGroups.map(\.displayName) == ["first", "second", "unpinned"])

        let busier = Conversation.fixture(projectPath: second.projectPath, updatedAt: .now + 100)
        store.replaceConversations(on: .thisMac, with: [first, second, busier, unpinned])
        #expect(store.sidebarProjectGroups.map(\.displayName) == ["first", "second", "unpinned"])

        store.movePinnedProject(second.projectDirectoryKey, to: .before(first.projectDirectoryKey))
        #expect(store.sidebarProjectGroups.map(\.displayName) == ["second", "first", "unpinned"])

        store.movePinnedProject(unpinned.projectDirectoryKey, to: .after(second.projectDirectoryKey))
        #expect(store.sidebarProjectGroups.map(\.displayName) == ["second", "unpinned", "first"])
        #expect(store.sidebarProjectGroups.allSatisfy { $0.isPinned })

        let relaunchedStore = makeStore(isolatedUserDefaults)
        relaunchedStore.replaceConversations(on: .thisMac, with: [first, second, busier, unpinned])
        #expect(relaunchedStore.sidebarProjectGroups.map(\.displayName) == ["second", "unpinned", "first"])
    }

    @Test func activityDoesNotReorderPinnedSessionsButADragDoes() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = makeStore(isolatedUserDefaults)
        let first = Conversation.fixture(updatedAt: .now - 200)
        let second = Conversation.fixture(updatedAt: .now - 100)
        let unpinned = Conversation.fixture(updatedAt: .now)
        store.replaceConversations(on: .thisMac, with: [first, second, unpinned])
        store.setPinned(true, conversation: first)
        store.setPinned(true, conversation: second)
        #expect(sessionIDs(in: store) == [first.id, second.id, unpinned.id])

        store.movePinnedConversation(second.id, to: .before(first.id))
        #expect(sessionIDs(in: store) == [second.id, first.id, unpinned.id])

        store.movePinnedConversation(unpinned.id, to: .last)
        #expect(sessionIDs(in: store) == [second.id, first.id, unpinned.id])
        #expect(store.pinnedItems.isPinned(conversationID: unpinned.id))

        let relaunchedStore = makeStore(isolatedUserDefaults)
        relaunchedStore.replaceConversations(on: .thisMac, with: [first, second, unpinned])
        #expect(sessionIDs(in: relaunchedStore) == [second.id, first.id, unpinned.id])
    }

    private func makeStore(_ isolatedUserDefaults: IsolatedUserDefaults) -> ConversationStore {
        ConversationStore(
            adapters: [],
            userDefaults: isolatedUserDefaults.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            startsBackgroundPolling: false
        )
    }

    private func sessionIDs(in store: ConversationStore) -> [String] {
        store.sidebarProjectGroups.first?.conversations.map(\.id) ?? []
    }
}
