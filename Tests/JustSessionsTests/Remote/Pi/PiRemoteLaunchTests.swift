import Foundation
import Testing
@testable import JustSessions

@MainActor
struct PiRemoteLaunchTests {
    @Test func resumingUsesPisSessionIDInTheSessionsProjectOverSSH() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let adapter = PiAdapter(sessionsDirectory: URL(fileURLWithPath: "/unused"))
        let store = ConversationStore(adapters: [adapter], userDefaults: settings.userDefaults)
        let conversation = Conversation.fixture(provider: .pi, projectPath: "/srv/Bob's paper", host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [conversation])

        store.launch(conversation, action: .resume)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.host == .ssh("devbox"))
        #expect(tab.command.executablePath == "/usr/bin/ssh")
        #expect(tab.conversation?.id == conversation.id)
        #expect(tab.command.arguments.last == RemoteCLICommandBuilder.remoteCommand(
            provider: .pi,
            projectPath: conversation.projectPath,
            arguments: ["--session", conversation.sessionID],
            tmuxSessionName: tab.tmuxSessionName
        ))
        store.closeAllTerminals()
    }

    @Test func branchingForksTheSessionInItsProjectAndWaitsForTheFork() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let adapter = PiAdapter(sessionsDirectory: URL(fileURLWithPath: "/unused"))
        let store = ConversationStore(adapters: [adapter], userDefaults: settings.userDefaults)
        let forked = Conversation.fixture(provider: .pi, projectPath: "/srv/app", host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [forked])

        #expect(store.canLaunch(forked, action: .branch))
        store.launch(forked, action: .branch)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.host == .ssh("devbox"))
        #expect(tab.conversation == nil)
        #expect(tab.pendingNewSession?.projectDirectoryKey == "ssh://devbox/srv/app")
        #expect(tab.command.arguments.last == RemoteCLICommandBuilder.remoteCommand(
            provider: .pi,
            projectPath: forked.projectPath,
            arguments: ["--fork", forked.sessionID],
            tmuxSessionName: tab.tmuxSessionName
        ))
        let fork = Conversation.fixture(provider: .pi, projectPath: forked.projectPath, host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [forked, fork])
        store.linkWaitingTabsByAppearance(on: .ssh("devbox"))

        #expect(tab.conversation?.id == fork.id)
        store.closeAllTerminals()
    }

    @Test func aNewPiSSHSessionLinksToItsOwnAppearingSession() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults)
        let existing = Conversation.fixture(provider: .pi, projectPath: "/srv/app", host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [existing])

        store.launchNewSessionFromProject(provider: .pi, projectPath: existing.projectDirectoryKey)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.command.arguments.last?.contains("exec pi") == true)
        #expect(tab.isNewSessionAwaitingConversation)
        let created = Conversation.fixture(provider: .pi, projectPath: existing.projectPath, host: .ssh("devbox"))
        let otherTool = Conversation.fixture(provider: .codex, projectPath: existing.projectPath, host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [existing, otherTool, created])
        store.linkWaitingTabsByAppearance(on: .ssh("devbox"))

        #expect(tab.conversation?.id == created.id)
        #expect(!tab.isNewSessionAwaitingConversation)
        store.closeAllTerminals()
    }
}
