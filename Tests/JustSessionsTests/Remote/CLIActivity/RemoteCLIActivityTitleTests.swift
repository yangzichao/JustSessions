import Foundation
import Testing

@testable import JustSessions

@MainActor
struct RemoteCLIActivityTitleTests {
    private static let prefix = RemoteCLIActivityTitle.titlePrefix

    @Test func readsTheRecordAsTheRegistryOnThisMacIsRead() {
        let records: [(String, CLIActivity)] = [
            ("busy:", .working),
            ("waiting:input needed", .needsInput(reason: "input needed")),
            ("waiting:dialog open", .needsInput(reason: "dialog open")),
            ("waiting:", .needsInput(reason: nil)),
            ("idle:", .idle),
            ("shell:", .idle),
            ("idle:input needed", .idle),
        ]
        for (record, activity) in records {
            #expect(RemoteCLIActivityTitle.activity(inTerminalTitle: Self.prefix + record, of: .claude) == activity, "\(record)")
        }
    }

    @Test func readsPisAndOpenCodesReportAsTheirReportsOnThisMacAreRead() {
        let reports: [(String, CLIActivity)] = [
            ("working:", .working),
            ("waiting:Allow rm -rf build?", .needsInput(reason: "Allow rm -rf build?")),
            ("waiting:Pick one: a or b", .needsInput(reason: "Pick one: a or b")),
            ("waiting:permission", .needsInput(reason: "permission")),
            ("waiting:", .needsInput(reason: nil)),
            ("idle:", .idle),
        ]
        for provider in [ConversationProvider.pi, .opencode] {
            for (report, activity) in reports {
                let title = Self.prefix + report
                #expect(RemoteCLIActivityTitle.activity(inTerminalTitle: title, of: provider) == activity, "\(provider) \(report)")
            }
            #expect(RemoteCLIActivityTitle.activity(inTerminalTitle: Self.prefix + "busy:", of: provider) == nil)
        }
        #expect(RemoteCLIActivityTitle.activity(inTerminalTitle: Self.prefix + "working:", of: .claude) == nil)
        #expect(RemoteCLIActivityTitle.activity(inTerminalTitle: Self.prefix + "working:", of: .codex) == nil)
    }

    /// The CLI's own title before its option is first set, or with tmux 2.6 the prefix alone.
    @Test func otherTitlesTellNothing() {
        let titles = [
            "", "✳ Claude Code", "✳ Fix login", "π - api", "OpenCode", Self.prefix, Self.prefix + ":",
            Self.prefix + "compacting:", "Ready | 01a10846",
        ]
        for provider in RemoteCLIActivityTitle.providers {
            for title in titles {
                #expect(RemoteCLIActivityTitle.activity(inTerminalTitle: title, of: provider) == nil, "\(provider) \(title)")
            }
        }
    }

    @Test func onAnSSHHostEachRelayedTabIsAskedOnlyItsTitle() {
        for provider in RemoteCLIActivityTitle.providers {
            let tab = Self.makeTab(for: .fixture(provider: provider, projectPath: "/srv/app", host: .ssh("devbox")))
            tab.updateTerminalTitle(Self.prefix + "idle:")
            let probe = tab.cliActivityProbe
            #expect(probe?.provider == provider)
            #expect(probe?.processID == 0)
            #expect(probe?.terminalTitle == Self.prefix + "idle:")
            #expect(probe?.sessionFile == nil)
        }

        #expect(RemoteCLIActivityTitle.providers == [.claude, .pi, .opencode, .kiro, .antigravity])
    }

    @Test func aClaudeCodeTabOnAnSSHHostShowsItsTurnsNotifiesAndStaysMarkedUnseen() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversation = Conversation.fixture(provider: .claude, projectPath: "/srv/app", title: "Fix login", host: .ssh("devbox"))
        let notifier = RecordingSessionNotifier()
        let store = ConversationStore(adapters: [], sessionNotifier: notifier)
        store.replaceConversations(on: .ssh("devbox"), with: [conversation])
        defer { store.closeAllTerminals() }
        let tab = Self.makeTab(for: conversation)
        tab.startIfNeeded()
        store.openTerminal(tab)
        let registry = ClaudeLiveSessionRegistry(configurationDirectory: directory.appendingPathComponent("claude"))
        func sync(record: String) async {
            tab.updateTerminalTitle(Self.prefix + record)
            await store.synchronizeCLIActivity(claudeRegistry: registry, liveSessionReporting: nil)
        }
        var isWaitingForYou: Bool { store.sessionsWaitingForYou.conversationIDs.contains(conversation.id) }

        await sync(record: "busy:")
        #expect(tab.cliActivity == .working)
        #expect(store.activitySummary(forProjectDirectoryKey: conversation.projectDirectoryKey).summary == "1 working")

        await sync(record: "waiting:input needed")
        #expect(tab.cliActivity == .needsInput(reason: "input needed"))
        #expect(isWaitingForYou)
        await sync(record: "busy:")
        await sync(record: "idle:")
        #expect(tab.cliActivity == .idle)

        #expect(notifier.notifications.map(\.reason) == [.needsInput(reason: "input needed"), .finishedTurn])
        #expect(notifier.notifications.allSatisfy { $0.source == .tab(id: tab.id, conversationID: conversation.id) })
        #expect(tab.hasUnseenFinishedTurn)
        #expect(tab.runStatus == .finishedUnseen)
        #expect(isWaitingForYou)
    }

    @Test(arguments: [ConversationProvider.pi, .opencode])
    func aPiOrOpenCodeTabOnAnSSHHostShowsItsTurnsNotifiesAndStaysMarkedUnseen(provider: ConversationProvider) async {
        let conversation = Conversation.fixture(provider: provider, projectPath: "/srv/app", title: "Port the parser", host: .ssh("devbox"))
        let notifier = RecordingSessionNotifier()
        let store = ConversationStore(adapters: [], sessionNotifier: notifier)
        store.replaceConversations(on: .ssh("devbox"), with: [conversation])
        defer { store.closeAllTerminals() }
        let tab = Self.makeTab(for: conversation)
        tab.startIfNeeded()
        store.openTerminal(tab)
        let registry = ClaudeLiveSessionRegistry(configurationDirectory: URL(fileURLWithPath: "/nonexistent"))
        func sync(report: String) async {
            tab.updateTerminalTitle(Self.prefix + report)
            await store.synchronizeCLIActivity(claudeRegistry: registry, liveSessionReporting: nil)
        }

        await sync(report: "working:")
        #expect(tab.cliActivity == .working)
        await sync(report: "waiting:permission")
        #expect(tab.cliActivity == .needsInput(reason: "permission"))
        #expect(store.sessionsWaitingForYou.conversationIDs.contains(conversation.id))
        await sync(report: "working:")
        await sync(report: "idle:")

        #expect(notifier.notifications.map(\.reason) == [.needsInput(reason: "permission"), .finishedTurn])
        #expect(tab.hasUnseenFinishedTurn)
        #expect(tab.runStatus == .finishedUnseen)
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
