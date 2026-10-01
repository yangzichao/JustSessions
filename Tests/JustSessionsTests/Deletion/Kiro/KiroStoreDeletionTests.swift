import Foundation
import Testing
@testable import JustSessions

@MainActor
struct KiroStoreDeletionTests {
    @Test(arguments: ["single", "selection", "project"])
    func deletedSessionsStayGoneAfterRefreshAndTheirProjectStaysVisible(_ deletionKind: String) async throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let retainedSessionID = UUID().uuidString.lowercased()
        try KiroSessionFolderFixture(sessionsDirectory: fixture.sessionsDirectory).writeSession(
            id: retainedSessionID,
            projectPath: fixture.root.path,
            messageLines: [KiroSessionFolderFixture.prompt("Keep me")]
        )
        let adapter = KiroAdapter(sessionsDirectory: fixture.sessionsDirectory, deletionExecutableURL: try fixture.executable())
        let store = ConversationStore(adapters: [adapter], userDefaults: isolatedUserDefaults.userDefaults)
        store.replaceConversations(on: .thisMac, with: try adapter.discover())
        let selected = try #require(store.conversations.first { $0.sessionID == fixture.conversation.sessionID })
        store.rename(selected, to: "Custom title")
        store.setPinned(true, conversation: selected)
        #expect(selected.supportsDeletionFromLauncher)
        #expect(selected.onHost(.ssh("devbox")).supportsDeletionFromLauncher)
        #expect(store.deletionPlan(for: [selected]).deletableConversations.map(\.id) == [selected.id])

        switch deletionKind {
        case "single": store.delete(selected)
        case "selection": store.deleteConversations([selected])
        default: store.deleteSessions(in: selected.projectDirectoryKey)
        }
        #expect(store.isDeletionPending(for: selected))
        try await expectEventually { !store.isDeletingSessions }
        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }

        #expect(store.errorMessage == nil)
        #expect(store.conversations.map(\.sessionID) == [retainedSessionID])
        #expect(!ConversationTitleAliases.load(from: isolatedUserDefaults.userDefaults).customTitlesByConversationID.keys.contains(selected.id))
        #expect(!PinnedItems.load(from: isolatedUserDefaults.userDefaults).isPinned(conversationID: selected.id))
        #expect(store.sidebarProjectGroups.contains { $0.id == selected.projectDirectoryKey && $0.sessionCount == 0 })
    }

    @Test func aRunningKiroSessionIsSkippedWithoutInvokingTheCLI() throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let adapter = KiroAdapter(sessionsDirectory: fixture.sessionsDirectory, deletionExecutableURL: try fixture.executable())
        let store = ConversationStore(adapters: [adapter], userDefaults: isolatedUserDefaults.userDefaults)
        store.replaceConversations(on: .thisMac, with: try adapter.discover())
        let selected = try #require(store.conversations.first)
        store.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(selected)]

        let plan = store.deletionPlan(for: [selected])
        #expect(plan.openTerminalCount == 1)
        #expect(plan.deletableConversations.isEmpty)
        store.delete(selected)
        store.deleteConversations([selected])
        store.deleteSessions(in: selected.projectDirectoryKey)

        #expect(!store.isDeletingSessions)
        #expect(store.errorMessage == ConversationDeletionError.activeTerminal.localizedDescription)
        #expect(FileManager.default.fileExists(atPath: selected.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: fixture.metadataFile.path))
    }

    @Test func aSessionLockedInAnotherProcessKeepsItsTitlePinAndHistory() async throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let executable = try fixture.executable(running: "#!/bin/sh\necho 'Session is active in another process' >&2\nexit 1\n")
        let adapter = KiroAdapter(sessionsDirectory: fixture.sessionsDirectory, deletionExecutableURL: executable)
        let store = ConversationStore(adapters: [adapter], userDefaults: isolatedUserDefaults.userDefaults)
        store.replaceConversations(on: .thisMac, with: try adapter.discover())
        let selected = try #require(store.conversations.first)
        store.rename(selected, to: "Keep this title")
        store.setPinned(true, conversation: selected)

        store.delete(selected)
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.errorMessage == KiroConversationDeletionError.failed("Session is active in another process").localizedDescription)
        #expect(store.conversations.map(\.id) == [selected.id])
        #expect(store.title(for: selected) == "Keep this title")
        #expect(store.pinnedItems.isPinned(conversationID: selected.id))
        #expect(FileManager.default.fileExists(atPath: selected.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: fixture.metadataFile.path))
    }
}
