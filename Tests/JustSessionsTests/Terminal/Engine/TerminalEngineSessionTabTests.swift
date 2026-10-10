import AppKit
import Foundation
import Testing
@testable import JustSessions

/// Every kind of session tab opens with the engine chosen in Settings at that moment, drawn by that engine's own
/// terminal: resuming, a new session, and a branch, on this Mac with and without tmux and on an SSH host.
@MainActor
struct TerminalEngineSessionTabTests {
    /// No refresh has checked the tmux version, so the CLI runs directly in the tab.
    @Test(arguments: TerminalEngine.allCases)
    func resumingASessionOnThisMacWithoutTmuxOpensWithTheChosenEngine(_ engine: TerminalEngine) throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: engine)
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation()
        let store = sandbox.makeStore(listing: [conversation])

        store.launch(conversation, action: .resume)

        let tab = try #require(store.runningTerminal(for: conversation))
        #expect(tab.tmuxSessionName == nil)
        #expect(tab.engine == engine)
        #expect(engine.draws(tab.terminalView))
    }

    /// As when an SSH host's connection drops: resuming starts the session again in its ended tab, which is the same tab
    /// to you, so it keeps the engine it opened with.
    @Test(arguments: TerminalEngine.allCases)
    func resumingASessionWhoseTabEndedKeepsThatTabsEngine(_ engine: TerminalEngine) throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: engine)
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation()
        let store = sandbox.makeStore(listing: [conversation])
        store.launch(conversation, action: .resume)
        let endedTab = try #require(store.runningTerminal(for: conversation))
        endedTab.processFinished(exitCode: 0)
        sandbox.engineStore.setEngine(engine.otherEngine)

        store.launch(conversation, action: .resume)

        let resumedTab = try #require(store.terminalSessions.first { $0.conversation?.id == conversation.id })
        #expect(resumedTab.id != endedTab.id)
        #expect(!resumedTab.hasExited)
        #expect(resumedTab.engine == engine)
        #expect(engine.draws(resumedTab.terminalView))
    }

    @Test(arguments: TerminalEngine.allCases)
    func aNewSessionOnThisMacOpensWithTheChosenEngine(_ engine: TerminalEngine) throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: engine)
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()

        // Codex, since a new Claude Code session first asks the installed `claude` whether it takes a session id.
        try store.launchNewSession(provider: .codex, in: sandbox.projectLocation)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.startsNewSession)
        #expect(tab.engine == engine)
        #expect(engine.draws(tab.terminalView))
    }

    @Test(arguments: TerminalEngine.allCases)
    func aBranchOpensWithTheChosenEngine(_ engine: TerminalEngine) throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: engine)
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation()
        let store = sandbox.makeStore(listing: [conversation])

        store.launch(conversation, action: .branch)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.action == .branch)
        #expect(tab.branchedFromSessionID == conversation.sessionID)
        #expect(tab.engine == engine)
        #expect(engine.draws(tab.terminalView))
    }

    /// The tab never starts, so nothing connects to the host.
    @Test(arguments: TerminalEngine.allCases)
    func aNewSessionOnAnSSHHostOpensWithTheChosenEngine(_ engine: TerminalEngine) throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: engine)
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()

        // Codex, since a new Claude Code session first asks the host's `claude` whether it takes a session id.
        try store.launchNewSession(provider: .codex, in: ProjectLocation(host: .ssh("devbox"), path: "/srv/project"))

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.host == .ssh("devbox"))
        #expect(tab.startsNewSession)
        #expect(tab.engine == engine)
        #expect(engine.draws(tab.terminalView))
    }

    /// The tab never starts, so nothing connects to the host.
    @Test(arguments: TerminalEngine.allCases)
    func resumingASessionOnAnSSHHostOpensWithTheChosenEngine(_ engine: TerminalEngine) throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: engine)
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation(host: .ssh("devbox"))
        let store = sandbox.makeStore(listing: [conversation])

        store.launch(conversation, action: .resume)

        let tab = try #require(store.runningTerminal(for: conversation))
        #expect(tab.host == .ssh("devbox"))
        #expect(tab.tmuxSessionName == TmuxSessionName.forConversation(conversation))
        #expect(tab.engine == engine)
        #expect(engine.draws(tab.terminalView))
    }

    /// Runs the installed tmux in a sandbox server; see `ThisMacTmuxSandbox`. The tab starts, in a window, and its
    /// tmux client runs the session's CLI there.
    @Test(arguments: TerminalEngine.allCases)
    func resumingASessionInTmuxOnThisMacOpensWithTheChosenEngine(_ engine: TerminalEngine) async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        try sandbox.writeExecutable(named: "claude", script: "#!/bin/sh\necho RESUMED_IN_TMUX\nexec /bin/sleep 60\n")
        let conversation = Conversation.fixture(projectPath: sandbox.project.path)
        let store = ConversationStore(
            adapters: [StaticConversationAdapter(discoveredConversations: [conversation])],
            commandResolver: sandbox.resolver,
            userDefaults: settings.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            terminalEngineStore: try TerminalEngineStore.pinned(to: engine),
            startsBackgroundPolling: false
        )
        defer { store.closeAllTerminals() }
        // Tabs run the CLI directly until a refresh has checked the tmux version.
        store.refreshThisMac()
        #expect(await sandbox.waitUntil { !store.isScanningThisMac })
        let tmuxSessionName = TmuxSessionName.forConversation(conversation)

        store.launch(conversation, action: .resume)

        let tab = try #require(store.runningTerminal(for: conversation))
        #expect(tab.tmuxSessionName == tmuxSessionName)
        #expect(tab.engine == engine)
        #expect(engine.draws(tab.terminalView))
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = tab.terminalView
        defer {
            window.contentView = nil
            window.close()
        }
        tab.startIfNeeded()
        #expect(await sandbox.waitUntil { sandbox.server.sessionNames() == [tmuxSessionName] }, "\(sandbox.launchDiagnostics(for: tab))")
        #expect(await sandbox.waitUntil { screenText(of: tab.terminalView).contains("RESUMED_IN_TMUX") }, "\(sandbox.launchDiagnostics(for: tab))")
    }
}
