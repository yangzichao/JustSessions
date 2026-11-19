import Foundation
import Testing

@testable import JustSessions

@MainActor
struct CodexTitleActivityTests {
    private static let threadID = "01a10846-4c77-75e2-bec8-ab638c1d2e3f"
    private static let cutThreadID = "01a10846-4c77-75e2-bec8-ab638..."

    @Test func readsTheRunStateWithOrWithoutTheSpinnerAndTheMicrophoneMark() {
        let titles: [(String, CLIActivity)] = [
            ("Ready | \(Self.cutThreadID)", .idle),
            ("Ready", .idle),
            ("⠧ Working | \(Self.cutThreadID)", .working),
            ("Working | \(Self.cutThreadID)", .working),
            ("● ⠋ Thinking | \(Self.cutThreadID)", .working),
            ("⠙ Waiting | \(Self.cutThreadID)", .working),
            ("Starting | \(Self.cutThreadID)", .working),
            ("⠹ Undoing | \(Self.cutThreadID)", .working),
            ("[ ! ] Action Required | \(Self.cutThreadID)", .needsInput(reason: nil)),
            ("[ . ] Action Required | \(Self.cutThreadID)", .needsInput(reason: nil)),
            ("● [ ! ] Action Required", .needsInput(reason: nil)),
        ]
        for (title, activity) in titles {
            #expect(CodexTitleActivity.activity(inTerminalTitle: title) == activity, "\(title)")
        }
    }

    @Test func otherTitlesTellNothing() {
        for title in ["", Self.cutThreadID, "Jonathans-MacBook-Pro.local", "✳ Claude Code", "增强按钮点击反馈 | JustSessions", "Working on it"] {
            #expect(CodexTitleActivity.activity(inTerminalTitle: title) == nil, "\(title)")
        }
    }

    @Test func theThreadIDIsTheTitlesLastItem() {
        #expect(CodexThreadTitle.threadIDPrefix(inTerminalTitle: "⠧ Working | \(Self.cutThreadID)") == "01a10846-4c77-75e2-bec8-ab638")
        #expect(CodexThreadTitle.threadIDPrefix(inTerminalTitle: "[ ! ] Action Required | \(Self.threadID)") == Self.threadID)
        #expect(CodexThreadTitle.threadIDPrefix(inTerminalTitle: "Ready") == nil)
        #expect(CodexThreadTitle.threadIDPrefix(inTerminalTitle: "Ready | \(Self.cutThreadID) ⠸") == "01a10846-4c77-75e2-bec8-ab638")
        #expect(CodexTitleActivity.activity(inTerminalTitle: "⠴ Working | \(Self.cutThreadID) ⠴") == .working)
    }

    @Test func aCodexTitleTellsMoreThanItsSessionFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let rolloutFile = directory.appendingPathComponent("rollout.jsonl")
        try CodexRolloutLines.write([CodexRolloutLines.sessionMeta, CodexRolloutLines.turnStarted(at: Date())], to: rolloutFile)
        let reader = CLIActivityReader(
            claudeRegistry: ClaudeLiveSessionRegistry(configurationDirectory: directory.appendingPathComponent("claude")),
            codexTurnTracker: CodexRolloutTurnTracker(),
            liveSessionReporting: nil
        )
        func probe(title: String?) -> CLIActivityProbe {
            CLIActivityProbe(provider: .codex, processID: 0, sessionFile: rolloutFile, terminalTitle: title)
        }

        let activities = reader.activities(for: [
            probe(title: "[ ! ] Action Required | \(Self.cutThreadID)"),
            probe(title: "Ready | \(Self.cutThreadID)"),
            probe(title: Self.cutThreadID),
            probe(title: nil),
        ])

        #expect(activities == [.needsInput(reason: nil), .idle, .working, .working])
    }

    @Test func onAnSSHHostACodexTabIsAskedOnlyItsTitle() {
        let codexTab = Self.makeTab(for: .fixture(provider: .codex, projectPath: "/srv/app", host: .ssh("devbox")))
        codexTab.updateTerminalTitle("⠧ Working | \(Self.cutThreadID)")
        let probe = codexTab.cliActivityProbe
        #expect(probe?.provider == .codex)
        #expect(probe?.terminalTitle == "⠧ Working | \(Self.cutThreadID)")
        #expect(probe?.sessionFile == nil)
        #expect(probe?.sessionID == nil)

    }

    @Test func aCodexTabOnAnSSHHostShowsItsTurnsAndNotifies() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversation = Conversation.fixture(provider: .codex, projectPath: "/srv/app", title: "Fix login", host: .ssh("devbox"))
        let notifier = RecordingSessionNotifier()
        let store = ConversationStore(adapters: [], sessionNotifier: notifier)
        store.replaceConversations(on: .ssh("devbox"), with: [conversation])
        defer { store.closeAllTerminals() }
        let tab = Self.makeTab(for: conversation)
        tab.startIfNeeded()
        store.openTerminal(tab)
        let registry = ClaudeLiveSessionRegistry(configurationDirectory: directory.appendingPathComponent("claude"))
        func sync(title: String) async {
            tab.updateTerminalTitle(title)
            await store.synchronizeCLIActivity(claudeRegistry: registry, liveSessionReporting: nil)
        }

        await sync(title: "⠧ Working | \(Self.cutThreadID)")
        #expect(tab.cliActivity == .working)
        #expect(store.activitySummary(forProjectDirectoryKey: conversation.projectDirectoryKey).summary == "1 working")

        await sync(title: "[ ! ] Action Required | \(Self.cutThreadID)")
        #expect(tab.cliActivity == .needsInput(reason: nil))
        await sync(title: "[ . ] Action Required | \(Self.cutThreadID)")
        await sync(title: "⠋ Working | \(Self.cutThreadID)")
        await sync(title: "Ready | \(Self.cutThreadID)")
        #expect(tab.cliActivity == .idle)

        #expect(notifier.notifications.map(\.reason) == [.needsInput(reason: nil), .finishedTurn])
        #expect(notifier.notifications.allSatisfy { $0.source == .tab(id: tab.id, conversationID: conversation.id) })
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
                workingDirectory: NSTemporaryDirectory(),
                environment: []
            ),
            host: conversation.host
        )
    }
}
