import Foundation
import Testing

@testable import JustSessions

/// Move to resumes a Claude Code session with `/cd <folder>` as its first message, so Claude Code moves it.
@MainActor
struct SessionMoveToFolderTests {
    private static let host = SessionHost.ssh("devbox")

    @Test func movingResumesTheSessionWithClaudeCodesCdCommand() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let session = Conversation.fixture(provider: .claude, projectPath: "/home/me/api", host: Self.host)
        let store = Self.makeStore(listing: [session], userDefaults: settings.userDefaults)
        defer { store.closeAllTerminals() }

        #expect(store.canMoveSession(session))
        store.moveSession(session, toFolder: "/home/me/web app")

        let tab = try #require(store.terminalSessions.only)
        #expect(tab.conversation?.id == session.id)
        // The remote command is quoted again for tmux, so only the words are checked.
        let remoteCommand = try #require(tab.command.arguments.last)
        #expect(remoteCommand.contains("--resume") && remoteCommand.contains(session.sessionID))
        #expect(remoteCommand.contains("/cd /home/me/web app"))
    }

    @Test func movingAnArchivedSessionUnarchivesIt() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let session = Conversation.fixture(provider: .claude, projectPath: "/home/me/api", host: Self.host)
        let store = Self.makeStore(listing: [session], userDefaults: settings.userDefaults)
        defer { store.closeAllTerminals() }
        store.setArchived(true, conversations: [session])

        store.moveSession(session, toFolder: "/home/me/web app")

        #expect(store.terminalSessions.only?.conversation?.id == session.id)
        #expect(!store.archivedSessions.isArchived(conversationID: session.id))
    }

    @Test func aSessionWhoseCLIRunsIsNotMoved() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let session = Conversation.fixture(provider: .claude, projectPath: "/home/me/api", host: Self.host)
        let store = Self.makeStore(listing: [session], userDefaults: settings.userDefaults)
        defer { store.closeAllTerminals() }
        store.tmuxSessionNamesByHost[Self.host] = [TmuxSessionName.forConversation(session)]

        #expect(!store.canMoveSession(session))
        store.moveSession(session, toFolder: "/home/me/web")
        #expect(store.terminalSessions.isEmpty)
    }

    @Test func onlyClaudeCodeSessionsMove() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let codexSession = Conversation.fixture(provider: .codex, projectPath: "/home/me/api", host: Self.host)
        let store = Self.makeStore(listing: [codexSession], userDefaults: settings.userDefaults)

        #expect(!store.canMoveSession(codexSession))
    }

    @Test func movingToTheSessionsOwnFolderDoesNothing() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let session = Conversation.fixture(provider: .claude, projectPath: "/home/me/api", host: Self.host)
        let store = Self.makeStore(listing: [session], userDefaults: settings.userDefaults)
        defer { store.closeAllTerminals() }

        store.moveSession(session, toFolder: "/home/me/api")
        #expect(store.terminalSessions.isEmpty)
    }

    @Test func claudeCodeGetsCdAsItsFirstMessage() {
        #expect(ConversationProvider.claude.moveToFolderArguments("/Users/me/web app") == ["/cd /Users/me/web app"])
    }

    private static func makeStore(listing conversations: [Conversation], userDefaults: UserDefaults) -> ConversationStore {
        let store = ConversationStore(adapters: [ClaudeAdapter()], userDefaults: userDefaults, startsBackgroundPolling: false)
        store.remoteHostList = RemoteHostList(hosts: ["devbox"])
        store.replaceConversations(on: host, with: conversations)
        return store
    }
}

extension Array {
    fileprivate var only: Element? { count == 1 ? first : nil }
}
