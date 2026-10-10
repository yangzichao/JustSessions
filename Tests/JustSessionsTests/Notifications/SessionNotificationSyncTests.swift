import Foundation
import Testing
@testable import JustSessions

/// The CLI activity sync posting notifications, and clicks on them showing their session.
@MainActor
struct SessionNotificationSyncTests {
    @Test func aTabsCLIThatFinishesItsTurnNotifiesUnlessItsTabIsInView() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let rolloutFile = directory.appendingPathComponent("rollout.jsonl")
        let conversation = Conversation.fixture(provider: .codex, projectPath: directory.path, title: "Fix login", sourceFile: rolloutFile)
        let notifier = RecordingSessionNotifier()
        let store = Self.makeStore(listing: [conversation], searching: directory, notifier: notifier)
        defer { store.closeAllTerminals() }
        let tab = Self.startTab(for: conversation)
        store.openTerminal(tab)
        let cliStartedAt = try #require(RunningProcessInfo.startDate(of: tab.cliProcessID))
        let registry = Self.emptyClaudeRegistry(in: directory)
        try CodexRolloutLines.write([CodexRolloutLines.sessionMeta, CodexRolloutLines.turnStarted(at: cliStartedAt + 1)], to: rolloutFile)
        await store.synchronizeCLIActivity(claudeRegistry: registry)
        #expect(tab.cliActivity == .working)

        // The app is in front with the tab selected, so you see the turn end.
        notifier.isApplicationActive = true
        try CodexRolloutLines.append(CodexRolloutLines.text([CodexRolloutLines.turnCompleted()]), to: rolloutFile)
        await store.synchronizeCLIActivity(claudeRegistry: registry)
        #expect(tab.cliActivity == .idle)
        #expect(notifier.notifications.isEmpty)

        try CodexRolloutLines.append(CodexRolloutLines.text([CodexRolloutLines.turnStarted(at: cliStartedAt + 2)]), to: rolloutFile)
        await store.synchronizeCLIActivity(claudeRegistry: registry)
        notifier.isApplicationActive = false
        try CodexRolloutLines.append(CodexRolloutLines.text([CodexRolloutLines.turnCompleted()]), to: rolloutFile)
        await store.synchronizeCLIActivity(claudeRegistry: registry)

        let notification = try #require(notifier.notifications.first)
        #expect(notifier.notifications.count == 1)
        #expect(notification == SessionNotification(
            source: .tab(id: tab.id, conversationID: conversation.id),
            reason: .finishedTurn,
            sessionTitle: "Fix login",
            provider: .codex,
            projectName: directory.lastPathComponent
        ))
        #expect(notification.subtitle == "Codex · \(directory.lastPathComponent)")
        #expect(notification.body == "Finished, waiting for your next prompt")
    }

    @Test func aCLIInTheSplitPaneBesideTheSelectedTabIsInView() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let rolloutFile = directory.appendingPathComponent("rollout.jsonl")
        let conversation = Conversation.fixture(provider: .codex, projectPath: directory.path, title: "Fix login", sourceFile: rolloutFile)
        let other = Conversation.fixture(provider: .codex, projectPath: directory.path)
        let notifier = RecordingSessionNotifier()
        notifier.isApplicationActive = true
        let store = Self.makeStore(listing: [conversation, other], searching: directory, notifier: notifier)
        defer { store.closeAllTerminals() }
        let tab = Self.startTab(for: conversation)
        store.openTerminal(tab)
        store.openTerminal(Self.makeTab(for: other))
        store.splitSelectedTerminal(with: tab.id)
        #expect(store.selectedTerminalID != tab.id)
        #expect(store.shownSplit?.contains(tab.id) == true)
        let cliStartedAt = try #require(RunningProcessInfo.startDate(of: tab.cliProcessID))
        let registry = Self.emptyClaudeRegistry(in: directory)
        try CodexRolloutLines.write([CodexRolloutLines.sessionMeta, CodexRolloutLines.turnStarted(at: cliStartedAt + 1)], to: rolloutFile)
        await store.synchronizeCLIActivity(claudeRegistry: registry)
        #expect(tab.cliActivity == .working)

        // The tab is not selected, but its terminal shows beside the selected one, so you see the turn end.
        try CodexRolloutLines.append(CodexRolloutLines.text([CodexRolloutLines.turnCompleted()]), to: rolloutFile)
        await store.synchronizeCLIActivity(claudeRegistry: registry)
        #expect(tab.cliActivity == .idle)
        #expect(notifier.notifications.isEmpty)

        // Once the split ends, the tab is out of view and the next turn's end notifies.
        store.separateSplit(try #require(store.shownSplit).id)
        try CodexRolloutLines.append(CodexRolloutLines.text([CodexRolloutLines.turnStarted(at: cliStartedAt + 2)]), to: rolloutFile)
        await store.synchronizeCLIActivity(claudeRegistry: registry)
        try CodexRolloutLines.append(CodexRolloutLines.text([CodexRolloutLines.turnCompleted()]), to: rolloutFile)
        await store.synchronizeCLIActivity(claudeRegistry: registry)
        #expect(notifier.notifications.count == 1)
    }

    @Test func aCLIInTmuxWithNoTabNotifiesWhenItStopsForAPrompt() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversation = Conversation.fixture(provider: .claude, projectPath: directory.path, title: "Paper")
        let notifier = RecordingSessionNotifier()
        notifier.isApplicationActive = true
        let store = Self.makeStore(listing: [conversation], searching: directory, notifier: notifier)
        // Stands in for the CLI in a tmux session whose tab closed.
        let cli = Process()
        cli.executableURL = URL(fileURLWithPath: StandInCLI.executablePath)
        cli.arguments = StandInCLI.arguments
        try cli.run()
        defer { if cli.isRunning { cli.terminate() } }
        let tmuxSessionName = TmuxSessionName.forConversation(conversation)
        store.tmuxSessionNamesByHost[.thisMac] = [tmuxSessionName]
        store.thisMacTmuxPaneProcessIDs[tmuxSessionName] = cli.processIdentifier
        let registry = Self.emptyClaudeRegistry(in: directory)
        try FileManager.default.createDirectory(at: registry.sessionsDirectory, withIntermediateDirectories: true)
        let recordFile = registry.sessionsDirectory.appendingPathComponent("\(cli.processIdentifier).json")

        try #"{"sessionId":"\#(conversation.sessionID)","status":"busy"}"#.write(to: recordFile, atomically: true, encoding: .utf8)
        await store.synchronizeCLIActivity(claudeRegistry: registry)
        #expect(notifier.notifications.isEmpty)

        try #"{"sessionId":"\#(conversation.sessionID)","status":"waiting","waitingFor":"input needed"}"#
            .write(to: recordFile, atomically: true, encoding: .utf8)
        await store.synchronizeCLIActivity(claudeRegistry: registry)

        let notification = try #require(notifier.notifications.first)
        #expect(notifier.notifications.count == 1)
        #expect(notification.source == .detachedTmux(conversationID: conversation.id))
        #expect(notification.reason == .needsInput(reason: "input needed"))
        #expect(notification.title == "Paper")
        #expect(notification.body == "Needs your input (input needed)")
    }

    @Test func clickingANotificationShowsTheTabThatRunsItsSession() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = Conversation.fixture(provider: .codex, projectPath: directory.path)
        let second = Conversation.fixture(provider: .codex, projectPath: directory.path)
        let store = Self.makeStore(listing: [first, second], searching: directory, notifier: RecordingSessionNotifier())
        defer { store.closeAllTerminals() }
        let firstTab = Self.makeTab(for: first)
        let secondTab = Self.makeTab(for: second)
        store.openTerminal(firstTab)
        store.openTerminal(secondTab)

        #expect(store.showTab(notifiedAbout: .tab(id: firstTab.id, conversationID: first.id)))
        #expect(store.selectedTerminalID == firstTab.id)
        // The CLI ran in tmux with no tab when it notified; a tab opened on it since.
        #expect(store.showTab(notifiedAbout: .detachedTmux(conversationID: second.id)))
        #expect(store.selectedTerminalID == secondTab.id)
        #expect(!store.showTab(notifiedAbout: .detachedTmux(conversationID: "gone")))
        #expect(store.selectedTerminalID == secondTab.id)
    }

    /// Finds no tmux, so the app's own tmux server is never asked.
    private static func makeStore(
        listing conversations: [Conversation],
        searching directory: URL,
        notifier: RecordingSessionNotifier
    ) -> ConversationStore {
        let store = ConversationStore(
            adapters: [],
            commandResolver: NativeCLICommandResolver(searchDirectories: [directory.path], inheritedEnvironment: [:]),
            sessionNotifier: notifier
        )
        store.replaceConversations(on: .thisMac, with: conversations)
        return store
    }

    private static func makeTab(for conversation: Conversation) -> TerminalSession {
        TerminalSession(
            engine: .swiftTerm,
            conversation: conversation,
            provider: conversation.provider,
            projectPath: conversation.projectPath,
            action: .resume,
            displayTitle: conversation.suggestedTitle,
            command: NativeCLICommand(
                executablePath: StandInCLI.executablePath,
                arguments: StandInCLI.arguments,
                workingDirectory: conversation.projectPath,
                environment: []
            )
        )
    }

    private static func startTab(for conversation: Conversation) -> TerminalSession {
        let tab = makeTab(for: conversation)
        tab.startIfNeeded()
        return tab
    }

    private static func emptyClaudeRegistry(in directory: URL) -> ClaudeLiveSessionRegistry {
        ClaudeLiveSessionRegistry(configurationDirectory: directory.appendingPathComponent("claude"))
    }
}
