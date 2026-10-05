import Foundation
import Testing
@testable import JustSessions

/// A subagent's session stays out of the listed sessions, is found under the session that started it, and is only
/// read: never launched or deleted on its own.
@MainActor
struct SubagentConversationsTests {
    @Test func subagentsAreKeptApartAndFoundUnderTheSessionThatStartedThem() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults)
        let parent = Conversation.fixture(provider: .pi, projectPath: "/work/app", updatedAt: .now)
        let older = Conversation.fixture(provider: .pi, projectPath: "/work/app", updatedAt: .now - 60, parentSessionID: parent.sessionID)
        let newer = Conversation.fixture(provider: .pi, projectPath: "/work/other", updatedAt: .now - 10, parentSessionID: parent.sessionID)
        let nested = Conversation.fixture(provider: .pi, projectPath: "/work/app", parentSessionID: older.sessionID)

        store.replaceConversations(on: .thisMac, with: [older, parent, nested, newer])

        #expect(store.conversations.map(\.id) == [parent.id])
        #expect(store.subagents(of: parent).map(\.id) == [newer.id, older.id])
        #expect(store.subagents(of: older).map(\.id) == [nested.id])
        #expect(store.conversation(withID: nested.id)?.parentID == older.id)
        // A subagent that ran in another folder adds no project to the sidebar.
        #expect(!store.sidebarProjectGroups.contains { $0.projectPath == "/work/other" })
    }

    @Test func eachHostKeepsItsOwnSubagents() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults)
        let parent = Conversation.fixture(provider: .codex)
        let subagent = Conversation.fixture(provider: .codex, parentSessionID: parent.sessionID)
        let remoteParent = Conversation.fixture(provider: .codex, host: .ssh("devbox"))
        let remoteSubagent = Conversation.fixture(provider: .codex, host: .ssh("devbox"), parentSessionID: remoteParent.sessionID)

        store.replaceConversations(on: .thisMac, with: [parent, subagent])
        store.replaceConversations(on: .ssh("devbox"), with: [remoteParent, remoteSubagent])
        store.replaceConversations(on: .thisMac, with: [parent])

        #expect(store.subagents(of: parent).isEmpty)
        #expect(store.subagents(of: remoteParent).map(\.id) == [remoteSubagent.id])
        #expect(remoteSubagent.parentID == remoteParent.id)
    }

    @Test func aSubagentIsNeitherLaunchedNorDeletedOnItsOwn() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults)
        let project = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: project) }
        let parent = Conversation.fixture(provider: .claude, projectPath: project.path)
        let subagent = Conversation.fixture(provider: .claude, projectPath: project.path, parentSessionID: parent.sessionID)
        store.replaceConversations(on: .thisMac, with: [parent, subagent])

        #expect(store.canLaunch(parent, action: .resume))
        #expect(!store.canLaunch(subagent, action: .resume))
        #expect(!store.canLaunch(subagent, action: .branch))
        #expect(store.canStartDeletion(of: [parent]))
        #expect(!store.canStartDeletion(of: [subagent]))
        #expect(!store.canStartDeletion(of: [parent, subagent]))
    }
}
