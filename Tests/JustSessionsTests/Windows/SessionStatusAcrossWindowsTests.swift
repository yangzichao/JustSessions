import Foundation
import Testing
@testable import JustSessions

/// A window shows a session whose tab is in another window by that tab: its row and project follow the tab's CLI,
/// the session is not taken for a CLI in tmux with no tab, and a clicked notification shows the tab where it is.
@MainActor
struct SessionStatusAcrossWindowsTests {
    @Test func aSessionsRowFollowsItsTabInAnotherWindowRatherThanTmux() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let tab = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.first))
        sandbox.second.setTmuxSessionNames([TmuxSessionName.forConversation(sandbox.conversation)], on: .thisMac)

        guard case .tab(let rowTab) = sandbox.second.sessionRowStatusSource(of: sandbox.conversation) else {
            Issue.record("The row should follow the other window's tab")
            return
        }
        #expect(rowTab.id == tab.id)
        // Counted once, as the tab's CLI, not again as one running in tmux.
        #expect(sandbox.second.activitySummary(forProjectDirectoryKey: sandbox.conversation.projectDirectoryKey).runningCount == 1)
    }

    @Test func aSessionWithATabInAnotherWindowCannotBeDeletedHere() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        #expect(!sandbox.second.hasTerminal(for: sandbox.conversation))

        _ = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.first))

        #expect(sandbox.second.hasTerminal(for: sandbox.conversation))
    }

    @Test func aCLIInTmuxWhoseTabIsInAnotherWindowIsNotFollowedHereAsDetached() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let rolloutFile = directory.appendingPathComponent("rollout.jsonl")
        try CodexRolloutLines.write([CodexRolloutLines.turnCompleted()], to: rolloutFile)
        let conversation = Conversation.fixture(provider: .codex, projectPath: directory.path, sourceFile: rolloutFile)
        let windowRegistry = WorkspaceWindowRegistry()
        let first = Self.makeStore(listing: [conversation], searching: directory, windowRegistry: windowRegistry)
        let second = Self.makeStore(listing: [conversation], searching: directory, windowRegistry: windowRegistry)
        defer {
            first.closeAllTerminals()
            second.closeAllTerminals()
        }
        second.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(conversation)]
        let claudeRegistry = ClaudeLiveSessionRegistry(configurationDirectory: directory.appendingPathComponent("claude"))
        await second.synchronizeCLIActivity(claudeRegistry: claudeRegistry)
        #expect(second.detachedCLIActivities == [conversation.id: .idle])

        let tab = TerminalSession(
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
        tab.startIfNeeded()
        first.openTerminal(tab)
        await first.synchronizeCLIActivity(claudeRegistry: claudeRegistry)
        await second.synchronizeCLIActivity(claudeRegistry: claudeRegistry)

        #expect(second.detachedCLIActivities.isEmpty)
        #expect(second.activitySummary(forProjectDirectoryKey: conversation.projectDirectoryKey).summary == "1 idle")
    }

    @Test func aClickedNotificationShowsTheTabInTheWindowThatHasIt() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let tab = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.second))
        let notificationCenter = SessionNotificationCenter(windowRegistry: sandbox.windowRegistry)

        notificationCenter.showSession(notifiedAbout: tab.attentionSource)

        #expect(sandbox.second.selectedTerminalID == tab.id)
        #expect(sandbox.first.terminalSessions.isEmpty)
    }

    /// Finds no tmux, so the app's own tmux server is never asked.
    private static func makeStore(
        listing conversations: [Conversation],
        searching directory: URL,
        windowRegistry: WorkspaceWindowRegistry
    ) -> ConversationStore {
        let store = ConversationStore(
            adapters: [],
            commandResolver: NativeCLICommandResolver(searchDirectories: [directory.path], inheritedEnvironment: [:]),
            sessionNotifier: RecordingSessionNotifier(),
            windowRegistry: windowRegistry,
            startsBackgroundPolling: false
        )
        store.replaceConversations(on: .thisMac, with: conversations)
        return store
    }
}
