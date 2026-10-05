import Foundation
import Testing
@testable import JustSessions

/// The New session sheet's start command is kept for the tool on the host, so resumes there start the same way.
@MainActor
struct StartCommandLaunchTests {
    private static let startCommand = #"~/.toolbox/bin/claude --aws-profile "dev""#

    @Test func aNewSessionsStartCommandAlsoResumesSessionsOnThatHost() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [ClaudeAdapter()], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        defer { store.closeAllTerminals() }

        try await store.launchNewSession(
            provider: .claude,
            host: .ssh("cloud"),
            folder: "~/api",
            startCommand: Self.startCommand,
            resolver: RemoteFolderResolver(runner: RemoteCommandRecorder().runner(answering: (0, "/home/me/api\n")))
        )
        let saved = Conversation.fixture(provider: .claude, projectPath: "/home/me/api", host: .ssh("cloud"))
        store.launch(saved, action: .resume)

        let newSessionCommand = try #require(store.terminalSessions.first?.command.arguments.last)
        let resumeCommand = try #require(store.terminalSessions.last?.command.arguments.last)
        #expect(store.terminalSessions.count == 2)
        // The remote command is quoted again for tmux, so only the start command's own text is checked as typed.
        #expect(newSessionCommand.contains("exec env \(Self.startCommand)"))
        #expect(resumeCommand.contains("exec env \(Self.startCommand) "))
        #expect(resumeCommand.contains("--resume") && resumeCommand.contains(saved.sessionID))
        #expect(CLIStartCommands.load(from: settings.userDefaults).customCommand(for: .claude, on: .ssh("cloud")) == Self.startCommand)
    }

    @Test func otherHostsKeepStartingTheToolsOwnExecutable() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [ClaudeAdapter()], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        defer { store.closeAllTerminals() }
        store.setStartCommand(Self.startCommand, for: .claude, on: .ssh("cloud"))

        store.launch(Conversation.fixture(provider: .claude, projectPath: "/home/me/api", host: .ssh("devbox")), action: .resume)

        let resumeCommand = try #require(store.terminalSessions.last?.command.arguments.last)
        #expect(!resumeCommand.contains("toolbox"))
        #expect(resumeCommand.contains("exec claude "))
    }
}
