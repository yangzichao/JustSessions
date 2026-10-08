import Foundation
import Testing
@testable import JustSessions

/// The sync on its own; `DetachedCLIActivityTmuxTests` runs it against a real tmux server.
@MainActor
struct CLIActivitySyncTests {
    @Test func followsATabsCodexCLIThroughItsTurns() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let rolloutFile = directory.appendingPathComponent("rollout.jsonl")
        let conversation = Conversation.fixture(provider: .codex, projectPath: directory.path, sourceFile: rolloutFile)
        let store = Self.makeStore(listing: [conversation], searching: directory)
        defer { store.closeAllTerminals() }
        let tab = Self.startTab(for: conversation, running: StandInCLI.executablePath, StandInCLI.arguments)
        store.openTerminal(tab)
        let cliStartedAt = try #require(RunningProcessInfo.startDate(of: tab.cliProcessID))
        try CodexRolloutLines.write([CodexRolloutLines.sessionMeta], to: rolloutFile)

        await store.synchronizeCLIActivity(claudeRegistry: Self.emptyClaudeRegistry(in: directory))
        #expect(tab.cliActivity == .idle)

        try CodexRolloutLines.append(CodexRolloutLines.text([CodexRolloutLines.turnStarted(at: cliStartedAt + 1)]), to: rolloutFile)
        await store.synchronizeCLIActivity(claudeRegistry: Self.emptyClaudeRegistry(in: directory))
        #expect(tab.cliActivity == .working)
        #expect(store.activitySummary(forProjectDirectoryKey: conversation.projectDirectoryKey).summary == "1 working")

        try CodexRolloutLines.append(CodexRolloutLines.text([CodexRolloutLines.turnCompleted()]), to: rolloutFile)
        await store.synchronizeCLIActivity(claudeRegistry: Self.emptyClaudeRegistry(in: directory))
        #expect(tab.cliActivity == .idle)
    }

    @Test func followsACLIRunningInTmuxWithNoTabUntilItEnds() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversation = Conversation.fixture(provider: .claude, projectPath: directory.path)
        let store = Self.makeStore(listing: [conversation], searching: directory)
        // Stands in for the CLI in a tmux session whose tab closed.
        let cli = Process()
        cli.executableURL = URL(fileURLWithPath: "/bin/sleep")
        cli.arguments = ["30"]
        try cli.run()
        defer { if cli.isRunning { cli.terminate() } }
        let tmuxSessionName = TmuxSessionName.forConversation(conversation)
        store.tmuxSessionNamesByHost[.thisMac] = [tmuxSessionName]
        store.thisMacTmuxPaneProcessIDs[tmuxSessionName] = cli.processIdentifier
        let claudeRegistry = try Self.claudeRegistry(
            in: directory,
            record: #"{"sessionId":"\#(conversation.sessionID)","status":"waiting","waitingFor":"input needed"}"#,
            forProcessID: cli.processIdentifier
        )

        await store.synchronizeCLIActivity(claudeRegistry: claudeRegistry)
        #expect(store.detachedCLIActivities == [conversation.id: .needsInput(reason: "input needed")])
        #expect(store.activitySummary(forProjectDirectoryKey: conversation.projectDirectoryKey).summary == "1 needs your input")

        cli.terminate()
        cli.waitUntilExit()
        await store.synchronizeCLIActivity(claudeRegistry: claudeRegistry)
        #expect(!store.isRunningInTmux(conversation))
        #expect(store.thisMacTmuxPaneProcessIDs[tmuxSessionName] == nil)
        #expect(store.detachedCLIActivities.isEmpty)
        #expect(store.activitySummary(forProjectDirectoryKey: conversation.projectDirectoryKey).runningCount == 0)
    }

    @Test func aTabOverTheSameSessionTakesOverFromTmux() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let rolloutFile = directory.appendingPathComponent("rollout.jsonl")
        try CodexRolloutLines.write([CodexRolloutLines.turnCompleted()], to: rolloutFile)
        let conversation = Conversation.fixture(provider: .codex, projectPath: directory.path, sourceFile: rolloutFile)
        let store = Self.makeStore(listing: [conversation], searching: directory)
        defer { store.closeAllTerminals() }
        store.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(conversation)]

        await store.synchronizeCLIActivity(claudeRegistry: Self.emptyClaudeRegistry(in: directory))
        #expect(store.detachedCLIActivities == [conversation.id: .idle])

        store.openTerminal(Self.startTab(for: conversation, running: StandInCLI.executablePath, StandInCLI.arguments))
        await store.synchronizeCLIActivity(claudeRegistry: Self.emptyClaudeRegistry(in: directory))
        #expect(store.detachedCLIActivities.isEmpty)
        #expect(store.activitySummary(forProjectDirectoryKey: conversation.projectDirectoryKey).summary == "1 idle")
    }

    /// Finds no tmux, so the app's own tmux server is never asked.
    private static func makeStore(listing conversations: [Conversation], searching directory: URL) -> ConversationStore {
        let store = ConversationStore(
            adapters: [],
            commandResolver: NativeCLICommandResolver(searchDirectories: [directory.path], inheritedEnvironment: [:])
        )
        store.replaceConversations(on: .thisMac, with: conversations)
        return store
    }

    private static func startTab(for conversation: Conversation, running executablePath: String, _ arguments: [String]) -> TerminalSession {
        let tab = TerminalSession(
            conversation: conversation,
            provider: conversation.provider,
            projectPath: conversation.projectPath,
            action: .resume,
            displayTitle: conversation.suggestedTitle,
            command: NativeCLICommand(
                executablePath: executablePath,
                arguments: arguments,
                workingDirectory: conversation.projectPath,
                environment: []
            )
        )
        tab.startIfNeeded()
        return tab
    }

    private static func emptyClaudeRegistry(in directory: URL) -> ClaudeLiveSessionRegistry {
        ClaudeLiveSessionRegistry(configurationDirectory: directory.appendingPathComponent("claude"))
    }

    private static func claudeRegistry(in directory: URL, record: String, forProcessID processID: Int32) throws -> ClaudeLiveSessionRegistry {
        let registry = emptyClaudeRegistry(in: directory)
        try FileManager.default.createDirectory(at: registry.sessionsDirectory, withIntermediateDirectories: true)
        try record.write(to: registry.sessionsDirectory.appendingPathComponent("\(processID).json"), atomically: true, encoding: .utf8)
        return registry
    }
}
