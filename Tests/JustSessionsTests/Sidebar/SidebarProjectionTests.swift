import Foundation
import Testing
@testable import JustSessions

/// The store keeps the sidebar's projects between store changes; each change they come from must still show.
@MainActor
struct SidebarProjectionTests {
    @Test func theSidebarFollowsEveryChangeAfterItWasWorkedOut() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(
            adapters: [],
            userDefaults: isolatedUserDefaults.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            startsBackgroundPolling: false
        )
        let older = Conversation.fixture(projectPath: "/tmp/justsessions-tests/older", updatedAt: .now - 100)
        let newer = Conversation.fixture(projectPath: "/tmp/justsessions-tests/newer", updatedAt: .now)
        store.replaceConversations(on: .thisMac, with: [older, newer])
        #expect(store.sidebarProjectGroups.map(\.displayName) == ["newer", "older"])

        store.setPinned(true, projectPath: older.projectDirectoryKey)
        #expect(store.sidebarProjectGroups.map(\.displayName) == ["older", "newer"])

        store.renameProject(newer.projectDirectoryKey, to: "Renamed")
        #expect(store.sidebarProjectGroups.map(\.displayName) == ["older", "Renamed"])

        store.removeProjectFromSidebar(older.projectDirectoryKey)
        #expect(store.sidebarProjectGroups.map(\.displayName) == ["Renamed"])
        #expect(store.sidebarConversations.map(\.id) == [newer.id])

        let added = Conversation.fixture(projectPath: newer.projectPath, updatedAt: .now + 100)
        store.replaceConversations(on: .thisMac, with: [newer, added])
        #expect(store.sidebarProjectGroups.first?.conversations.map(\.id) == [added.id, newer.id])
        #expect(store.conversation(withID: added.id)?.id == added.id)
    }
}
