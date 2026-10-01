import Foundation
import Testing
@testable import JustSessions

@MainActor
struct KiroRemoteLaunchTests {
    @Test func resumingUsesKirosSessionIDAndProjectOverSSH() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let adapter = KiroAdapter(sessionsDirectory: URL(fileURLWithPath: "/unused"))
        let store = ConversationStore(adapters: [adapter], userDefaults: settings.userDefaults)
        let conversation = Conversation.fixture(provider: .kiro, projectPath: "/srv/Bob's paper", host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [conversation])

        store.launch(conversation, action: .resume)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.host == .ssh("devbox"))
        #expect(tab.conversation?.id == conversation.id)
        #expect(tab.command.arguments.last == RemoteCLICommandBuilder.remoteCommand(
            provider: .kiro,
            projectPath: conversation.projectPath,
            arguments: ["chat", "--resume-id", conversation.sessionID],
            tmuxSessionName: tab.tmuxSessionName
        ))
        store.closeAllTerminals()
    }

    @Test func aNewKiroSSHSessionLinksToItsOwnAppearingSession() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults)
        let existing = Conversation.fixture(provider: .kiro, projectPath: "/srv/app", host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [existing])

        store.launchNewSessionFromProject(provider: .kiro, projectPath: existing.projectDirectoryKey)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.command.arguments.last?.contains("exec kiro-cli") == true)
        #expect(tab.isNewSessionAwaitingConversation)
        let created = Conversation.fixture(provider: .kiro, projectPath: existing.projectPath, host: .ssh("devbox"))
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
        let store = ConversationStore(adapters: [KiroAdapter()], userDefaults: settings.userDefaults)
        let conversation = Conversation.fixture(provider: .kiro, host: .ssh("devbox"))

        #expect(!store.canLaunch(conversation, action: .branch))
        store.launch(conversation, action: .branch)
        #expect(store.terminalSessions.isEmpty)
    }
}
