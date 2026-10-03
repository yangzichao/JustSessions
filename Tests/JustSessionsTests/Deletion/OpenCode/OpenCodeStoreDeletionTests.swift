import Foundation
import Testing
@testable import JustSessions

@MainActor
struct OpenCodeStoreDeletionTests {
    @Test(arguments: ["single", "selection", "project"])
    func deletedSessionsStayGoneAfterRefreshAndTheirProjectStaysVisible(_ deletionKind: String) async throws {
        let fixture = try OpenCodeDeletionFixture()
        defer { fixture.remove() }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let adapter = try fixture.adapter()
        let store = ConversationStore(adapters: [adapter], userDefaults: isolatedUserDefaults.userDefaults)
        store.replaceConversations(on: .thisMac, with: try adapter.discover())
        let selected = try #require(store.conversations.first { $0.sessionID == OpenCodeDeletionFixture.selectedSessionID })
        store.rename(selected, to: "Custom title")
        store.setPinned(true, conversation: selected)
        #expect(selected.supportsDeletionFromLauncher)
        #expect(store.deletionPlan(for: [selected]).deletableConversations.map(\.id) == [selected.id])

        switch deletionKind {
        case "single": store.delete(selected)
        case "selection": store.deleteConversations([selected])
        default: store.deleteSessions(in: selected.projectDirectoryKey)
        }
        try await expectEventually { !store.isDeletingSessions }
        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }

        #expect(store.errorMessage == nil)
        let expectedSessionIDs = deletionKind == "project" ? [] : [OpenCodeDeletionFixture.retainedSessionID]
        #expect(store.conversations.map(\.sessionID) == expectedSessionIDs)
        #expect(!ConversationTitleAliases.load(from: isolatedUserDefaults.userDefaults).customTitlesByConversationID.keys.contains(selected.id))
        #expect(!PinnedItems.load(from: isolatedUserDefaults.userDefaults).isPinned(conversationID: selected.id))
        #expect(store.sidebarProjectGroups.contains { $0.id == selected.projectDirectoryKey })
    }

    @Test func aFailedDeletionKeepsTheSessionListedWithItsTitle() async throws {
        let fixture = try OpenCodeDeletionFixture()
        defer { fixture.remove() }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let adapter = try fixture.adapter(running: "#!/bin/sh\necho 'database is locked' >&2\nexit 1\n")
        let store = ConversationStore(adapters: [adapter], userDefaults: isolatedUserDefaults.userDefaults)
        store.replaceConversations(on: .thisMac, with: try adapter.discover())
        let selected = try #require(store.conversations.first { $0.sessionID == OpenCodeDeletionFixture.selectedSessionID })
        store.rename(selected, to: "Custom title")

        store.delete(selected)
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.errorMessage == OpenCodeConversationDeletionError.failed("database is locked").localizedDescription)
        #expect(store.conversations.contains { $0.id == selected.id })
        #expect(ConversationTitleAliases.load(from: isolatedUserDefaults.userDefaults).customTitlesByConversationID[selected.id] == "Custom title")
    }
}
