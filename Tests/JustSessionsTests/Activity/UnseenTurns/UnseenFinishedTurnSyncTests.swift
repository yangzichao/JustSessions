import Foundation
import Testing
@testable import JustSessions

/// The CLI activity sync marking a Codex tab whose turn finished off screen, and looking at the tab clearing it.
@MainActor
struct UnseenFinishedTurnSyncTests {
    @Test func aTurnThatFinishesOffScreenStaysMarkedUntilItsTabIsSelected() async throws {
        let fixture = try Fixture(isApplicationActive: true)
        defer { fixture.tearDown() }
        let store = fixture.store
        // A second tab opens in front, so the Codex tab is off screen.
        store.openTerminal(Fixture.makeTab(for: fixture.otherConversation))
        #expect(store.selectedTerminalID != fixture.tab.id)

        try await fixture.startTurn()
        #expect(!fixture.isWaitingForYou)
        try await fixture.finishTurn()
        #expect(fixture.tab.hasUnseenFinishedTurn)
        #expect(fixture.tab.runStatus == .finishedUnseen)
        #expect(fixture.isWaitingForYou)
        #expect(store.activitySummary(forProjectDirectoryKey: fixture.tab.projectDirectoryKey).mostPressingStatus == .finishedUnseen)
        let waitingOnly = store.filteredSidebarProjection(
            providerFilter: .all, recencyFilter: .all, waitingFilter: .waitingForYou, searchText: ""
        )
        #expect(waitingOnly.projects.flatMap(\.conversations).map(\.id) == [fixture.conversation.id])
        #expect(waitingOnly.waitingSessionCount == 1)
        await fixture.synchronize()
        #expect(fixture.tab.hasUnseenFinishedTurn)

        // Seen as soon as it is selected, without waiting for the next sync.
        store.selectTerminal(fixture.tab.id)
        #expect(!fixture.tab.hasUnseenFinishedTurn)
        #expect(fixture.tab.runStatus == .running(.idle))
        #expect(!fixture.isWaitingForYou)
    }

    @Test func showingTheTabInASplitBesideTheSelectedOneMarksItSeen() async throws {
        let fixture = try Fixture(isApplicationActive: true)
        defer { fixture.tearDown() }
        let store = fixture.store
        store.openTerminal(Fixture.makeTab(for: fixture.otherConversation))
        try await fixture.startTurn()
        try await fixture.finishTurn()
        #expect(fixture.tab.hasUnseenFinishedTurn)

        store.splitSelectedTerminal(with: fixture.tab.id)
        #expect(store.shownSplit?.contains(fixture.tab.id) == true)
        #expect(!fixture.tab.hasUnseenFinishedTurn)
    }

    @Test func aTurnThatFinishesWhileTheAppIsBehindIsSeenOnceTheAppComesToTheFront() async throws {
        let fixture = try Fixture(isApplicationActive: false)
        defer { fixture.tearDown() }
        let store = fixture.store
        #expect(store.selectedTerminalID == fixture.tab.id)

        try await fixture.startTurn()
        try await fixture.finishTurn()
        #expect(fixture.tab.hasUnseenFinishedTurn)

        fixture.notifier.isApplicationActive = true
        await fixture.synchronize()
        #expect(!fixture.tab.hasUnseenFinishedTurn)
    }

    @Test func aTurnThatFinishesInViewIsNeverMarked() async throws {
        let fixture = try Fixture(isApplicationActive: true)
        defer { fixture.tearDown() }

        try await fixture.startTurn()
        try await fixture.finishTurn()
        #expect(!fixture.tab.hasUnseenFinishedTurn)
        #expect(!fixture.isWaitingForYou)
    }

    /// A store with a running Codex tab, selected, whose turns come from the rollout file the test writes.
    /// Finds no tmux, so the app's own tmux server is never asked.
    @MainActor
    private struct Fixture {
        let directory: URL
        let rolloutFile: URL
        let conversation: Conversation
        let otherConversation: Conversation
        let notifier = RecordingSessionNotifier()
        let store: ConversationStore
        let tab: TerminalSession
        let claudeRegistry: ClaudeLiveSessionRegistry
        let cliStartedAt: Date

        init(isApplicationActive: Bool) throws {
            directory = try makeTemporaryDirectory()
            rolloutFile = directory.appendingPathComponent("rollout.jsonl")
            conversation = Conversation.fixture(provider: .codex, projectPath: directory.path, sourceFile: rolloutFile)
            otherConversation = Conversation.fixture(provider: .codex, projectPath: directory.path)
            notifier.isApplicationActive = isApplicationActive
            store = ConversationStore(
                adapters: [],
                commandResolver: NativeCLICommandResolver(searchDirectories: [directory.path], inheritedEnvironment: [:]),
                sessionNotifier: notifier
            )
            store.replaceConversations(on: .thisMac, with: [conversation, otherConversation])
            tab = Self.makeTab(for: conversation)
            tab.startIfNeeded()
            store.openTerminal(tab)
            claudeRegistry = ClaudeLiveSessionRegistry(configurationDirectory: directory.appendingPathComponent("claude"))
            cliStartedAt = try #require(RunningProcessInfo.startDate(of: tab.cliProcessID))
        }

        func tearDown() {
            store.closeAllTerminals()
            try? FileManager.default.removeItem(at: directory)
        }

        /// The Codex tab's session is among those the Waiting for you filter keeps.
        var isWaitingForYou: Bool {
            store.sessionsWaitingForYou.conversationIDs.contains(conversation.id)
        }

        func synchronize() async {
            await store.synchronizeCLIActivity(claudeRegistry: claudeRegistry)
        }

        func startTurn() async throws {
            try CodexRolloutLines.write([CodexRolloutLines.sessionMeta, CodexRolloutLines.turnStarted(at: cliStartedAt + 1)], to: rolloutFile)
            await synchronize()
            #expect(tab.cliActivity == .working)
        }

        func finishTurn() async throws {
            try CodexRolloutLines.append(CodexRolloutLines.text([CodexRolloutLines.turnCompleted()]), to: rolloutFile)
            await synchronize()
            #expect(tab.cliActivity == .idle)
        }

        static func makeTab(for conversation: Conversation) -> TerminalSession {
            TerminalSession(
                conversation: conversation,
                provider: conversation.provider,
                projectPath: conversation.projectPath,
                action: .resume,
                displayTitle: conversation.suggestedTitle,
                command: NativeCLICommand(
                    executablePath: "/bin/sleep",
                    arguments: ["30"],
                    workingDirectory: conversation.projectPath,
                    environment: []
                )
            )
        }
    }
}
