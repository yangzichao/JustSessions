import Foundation
import Testing
@testable import JustSessions

/// After a light/dark change that tmux before 3.6 does not pass on, a Claude Code tab on an SSH host attaches its tmux
/// client again and reports the change once tmux has asked for the new colors.
@MainActor
struct RemoteTmuxReattachTests {
    @Test(arguments: TerminalEngine.allCases)
    func aClaudeCodeTabOnAnSSHHostAttachesAgainAndOwesAReport(engine: TerminalEngine) async throws {
        let recorder = RemoteReattachRecorder(exitStatus: 0)
        let store = ConversationStore(adapters: [], startsBackgroundPolling: false)
        let tab = Self.tab(engine: engine, provider: .claude, host: .ssh("devbox"))
        let tmuxSessionName = try #require(tab.tmuxSessionName)

        store.reattachRemoteTmuxClient(of: tab, remoteRunner: recorder.runner)

        try await expectEventually { recorder.calls.count == 1 }
        #expect(recorder.calls.first?.host == "devbox")
        #expect(recorder.calls.first?.command == RemoteTmuxCommands.reattachClientsCommand(tmuxSessionName, on: "devbox"))
        #expect(tab.terminalView.reportsThemeAfterNextBackgroundQuery)
    }

    /// Without tmux or its session on the host, no client asks for the colors, and a report owed until a later attach
    /// would arrive unasked.
    @Test(arguments: TerminalEngine.allCases)
    func aFailedReattachOwesNoReport(engine: TerminalEngine) async throws {
        let recorder = RemoteReattachRecorder(exitStatus: 1)
        let store = ConversationStore(adapters: [], startsBackgroundPolling: false)
        let tab = Self.tab(engine: engine, provider: .claude, host: .ssh("devbox"))

        store.reattachRemoteTmuxClient(of: tab, remoteRunner: recorder.runner)

        try await expectEventually { recorder.calls.count == 1 && !tab.terminalView.reportsThemeAfterNextBackgroundQuery }
    }

    @Test(arguments: TerminalEngine.allCases)
    func otherTabsAreLeftAlone(engine: TerminalEngine) async throws {
        let recorder = RemoteReattachRecorder(exitStatus: 0)
        let store = ConversationStore(adapters: [], startsBackgroundPolling: false)
        let tabs = [
            Self.tab(engine: engine, provider: .codex, host: .ssh("devbox")),
            Self.tab(engine: engine, provider: .claude, host: .thisMac),
            Self.tab(engine: engine, provider: .claude, host: .ssh("devbox"), startsOnceShown: true),
        ]

        for tab in tabs { store.reattachRemoteTmuxClient(of: tab, remoteRunner: recorder.runner) }

        try await Task.sleep(for: .milliseconds(200))
        #expect(recorder.calls.isEmpty)
        #expect(tabs.allSatisfy { !$0.terminalView.reportsThemeAfterNextBackgroundQuery })
    }

    @Test(arguments: TerminalEngine.allCases)
    func onlyAnSSHHostsClaudeCodeTabFollowsLightDarkChanges(engine: TerminalEngine) {
        let store = ConversationStore(adapters: [], startsBackgroundPolling: false)
        let remoteClaudeTab = Self.tab(engine: engine, provider: .claude, host: .ssh("devbox"))
        let remoteCodexTab = Self.tab(engine: engine, provider: .codex, host: .ssh("devbox"))
        let thisMacClaudeTab = Self.tab(engine: engine, provider: .claude, host: .thisMac)

        for tab in [remoteClaudeTab, remoteCodexTab, thisMacClaudeTab] { store.followLightDarkChanges(of: tab) }

        #expect(remoteClaudeTab.terminalView.onUnheardLightDarkChange != nil)
        #expect(remoteCodexTab.terminalView.onUnheardLightDarkChange == nil)
        #expect(thisMacClaudeTab.terminalView.onUnheardLightDarkChange == nil)
    }

    private static func tab(
        engine: TerminalEngine, provider: ConversationProvider, host: SessionHost, startsOnceShown: Bool = false
    ) -> TerminalSession {
        let conversation = Conversation.fixture(provider: provider, host: host)
        return TerminalSession(
            engine: engine,
            conversation: conversation,
            provider: provider,
            projectPath: conversation.projectPath,
            action: .resume,
            displayTitle: "Session",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: []),
            host: host,
            tmuxSessionName: TmuxSessionName.forConversation(conversation),
            startsOnceShown: startsOnceShown
        )
    }
}

/// Stands in for `ssh`, recording each command and answering with one exit status.
private final class RemoteReattachRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedCalls: [(host: String, command: String)] = []
    private let exitStatus: Int32

    init(exitStatus: Int32) {
        self.exitStatus = exitStatus
    }

    var calls: [(host: String, command: String)] { lock.withLock { recordedCalls } }

    var runner: RemoteHostCommandRunner {
        RemoteHostCommandRunner { host, command, _ in
            self.lock.withLock { self.recordedCalls.append((host, command)) }
            return (self.exitStatus, "")
        }
    }
}
