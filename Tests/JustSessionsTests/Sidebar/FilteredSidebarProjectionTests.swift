import Foundation
import Testing
@testable import JustSessions

@MainActor
struct FilteredSidebarProjectionTests {
    @Test func matchesFilteringTheProjectGroupsDirectly() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let recent = Conversation.fixture(provider: .claude, title: "Recent Claude session")
        let old = Conversation.fixture(
            provider: .codex,
            projectPath: "/tmp/justsessions-tests/other-project",
            title: "Old Codex session",
            updatedAt: .now.addingTimeInterval(-30 * 24 * 3_600)
        )
        let store = makeStore(listing: [recent, old], userDefaults: isolatedUserDefaults.userDefaults)

        let filtered = store.filteredSidebarProjection(providerFilter: .all, recencyFilter: .recent, searchText: "claude")

        let expectedProjects = SidebarProjectFiltering.projects(
            SidebarProjectFiltering.projects(store.sidebarProjectGroups, providerFilter: .all, recencyFilter: .recent),
            matching: "claude"
        ) { store.title(for: $0) }
        #expect(filtered.projects.map(\.id) == expectedProjects.map(\.id))
        #expect(filtered.projects.flatMap { $0.conversations.map(\.id) } == [recent.id])
        #expect(filtered.allSessionCount == 2)
        #expect(filtered.recentSessionCount == 1)
    }

    @Test func keepsTheAnswerUntilAFilterOrTheListedSessionsChange() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let newer = Conversation.fixture(title: "Session one")
        let older = Conversation.fixture(title: "Session two", updatedAt: .now.addingTimeInterval(-60))
        let store = makeStore(listing: [newer, older], userDefaults: isolatedUserDefaults.userDefaults)

        let first = store.filteredSidebarProjection(providerFilter: .all, recencyFilter: .all, searchText: "")
        #expect(first.projects.flatMap { $0.conversations.map(\.id) } == [newer.id, older.id])

        // A planted answer with the same inputs but no sessions: getting it back proves the next call read the
        // cache rather than recomputing.
        store.cachedFilteredSidebarProjection = FilteredSidebarProjection(
            inputs: first.inputs,
            projection: SidebarProjection(inputs: first.inputs.projectionInputs, conversations: []),
            title: { _ in "" }
        )
        let cached = store.filteredSidebarProjection(providerFilter: .all, recencyFilter: .all, searchText: "")
        #expect(cached.projects.flatMap(\.conversations).isEmpty)

        // Changing the listed sessions recomputes past the planted answer.
        store.replaceConversations(on: .thisMac, with: [newer])
        let afterReplacing = store.filteredSidebarProjection(providerFilter: .all, recencyFilter: .all, searchText: "")
        #expect(afterReplacing.projects.flatMap { $0.conversations.map(\.id) } == [newer.id])

        // So does pinning: the pinned session moves to the front of its project.
        store.replaceConversations(on: .thisMac, with: [newer, older])
        store.setPinned(true, conversation: older)
        let afterPinning = store.filteredSidebarProjection(providerFilter: .all, recencyFilter: .all, searchText: "")
        #expect(afterPinning.projects.flatMap { $0.conversations.map(\.id) } == [older.id, newer.id])

        // And the search text: a rename out of the match drops the session.
        let searched = store.filteredSidebarProjection(providerFilter: .all, recencyFilter: .all, searchText: "one")
        #expect(searched.projects.flatMap { $0.conversations.map(\.id) } == [newer.id])
        store.rename(newer, to: "Renamed beyond the search")
        let afterRename = store.filteredSidebarProjection(providerFilter: .all, recencyFilter: .all, searchText: "one")
        #expect(afterRename.projects.isEmpty)
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
