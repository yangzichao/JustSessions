import Foundation
import Testing
@testable import JustSessions

@MainActor
struct OpenCodeRemoteLaunchTests {
    @Test(arguments: [
        (ConversationAction.resume, ["--session", "ses_remote000001"]),
        (.branch, ["--session", "ses_remote000001", "--fork"]),
    ])
    func resumingAndBranchingRunOpenCodeInTheProjectOverSSH(action: ConversationAction, expectedArguments: [String]) throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [OpenCodeAdapter(databaseFile: URL(fileURLWithPath: "/unused"))], userDefaults: settings.userDefaults)
        let conversation = Conversation.fixture(provider: .opencode, sessionID: "ses_remote000001", projectPath: "/srv/Bob's paper", host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [conversation])

        #expect(store.canLaunch(conversation, action: action))
        store.launch(conversation, action: action)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.host == .ssh("devbox"))
        #expect(tab.command.arguments.last == RemoteCLICommandBuilder.remoteCommand(
            provider: .opencode,
            projectPath: conversation.projectPath,
            arguments: expectedArguments,
            tmuxSessionName: tab.tmuxSessionName
        ))
        store.closeAllTerminals()
    }

    @Test func aNewOpenCodeSSHSessionLinksToItsOwnAppearingSession() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults)
        let existing = Conversation.fixture(provider: .opencode, sessionID: "ses_existing0001", projectPath: "/srv/app", host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [existing])

        store.launchNewSessionFromProject(provider: .opencode, projectPath: existing.projectDirectoryKey)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.command.arguments.last?.contains("exec opencode") == true)
        #expect(tab.isNewSessionAwaitingConversation)
        let created = Conversation.fixture(provider: .opencode, sessionID: "ses_created00001", projectPath: existing.projectPath, host: .ssh("devbox"))
        let otherTool = Conversation.fixture(provider: .codex, projectPath: existing.projectPath, host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [existing, otherTool, created])
        store.linkWaitingTabsByAppearance(on: .ssh("devbox"))

        #expect(tab.conversation?.id == created.id)
        #expect(!tab.isNewSessionAwaitingConversation)
        store.closeAllTerminals()
    }
}
