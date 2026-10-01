import Foundation
import Testing
@testable import JustSessions

@MainActor
struct AntigravityRemoteLaunchTests {
    @Test func resumingUsesAntigravitysSessionIDAndProjectOverSSH() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let adapter = AntigravityAdapter(configurationDirectory: URL(fileURLWithPath: "/unused"))
        let store = ConversationStore(adapters: [adapter], userDefaults: settings.userDefaults)
        let conversation = Conversation.fixture(provider: .antigravity, projectPath: "/srv/Bob's paper", host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [conversation])

        store.launch(conversation, action: .resume)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.host == .ssh("devbox"))
        #expect(tab.conversation?.id == conversation.id)
        #expect(tab.command.arguments.last == RemoteCLICommandBuilder.remoteCommand(
            provider: .antigravity,
            projectPath: conversation.projectPath,
            arguments: ["--conversation", conversation.sessionID],
            tmuxSessionName: tab.tmuxSessionName
        ))
        store.closeAllTerminals()
    }

    @Test func aNewAntigravitySSHSessionLinksToItsOwnAppearingSession() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults)
        let existing = Conversation.fixture(provider: .antigravity, projectPath: "/srv/app", host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [existing])

        store.launchNewSessionFromProject(provider: .antigravity, projectPath: existing.projectDirectoryKey)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.command.arguments.last?.contains("exec agy") == true)
        #expect(tab.isNewSessionAwaitingConversation)
        let created = Conversation.fixture(provider: .antigravity, projectPath: existing.projectPath, host: .ssh("devbox"))
        let otherTool = Conversation.fixture(provider: .codex, projectPath: existing.projectPath, host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [existing, otherTool, created])
        store.linkWaitingTabsByAppearance(on: .ssh("devbox"))

        #expect(tab.conversation?.id == created.id)
        #expect(!tab.isNewSessionAwaitingConversation)
        store.closeAllTerminals()
    }

    @Test func unsupportedBranchingNeverOpensAResumeTabForTheOriginalSession() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [AntigravityAdapter()], userDefaults: settings.userDefaults)
        let conversation = Conversation.fixture(provider: .antigravity, host: .ssh("devbox"))

        #expect(!store.canLaunch(conversation, action: .branch))
        store.launch(conversation, action: .branch)
        #expect(store.terminalSessions.isEmpty)
    }
}
