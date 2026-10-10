import Foundation
import Testing
@testable import JustSessions

/// Moving a session's tab to another window opens a tab for it there, which is the same tab to you, so it keeps the
/// engine it had, as a reconnected SSH tab does, even after another engine was chosen.
@MainActor
struct TerminalEngineTabMovingTests {
    @Test(arguments: TerminalEngine.allCases)
    func aTabWaitingToBeShownKeepsItsEngineInItsNewWindow(_ engine: TerminalEngine) throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: engine)
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation()
        let first = sandbox.makeStore(listing: [conversation])
        let second = sandbox.makeStore(listing: [conversation])
        let waitingTab = try #require(try first.makeTerminal(for: conversation, action: .resume, startsOnceShown: true))
        // As a tab from the last quit that was not selected; selecting it would start it.
        first.insertReopenedTerminal(waitingTab, at: 0, selecting: false)
        sandbox.engineStore.setEngine(engine.otherEngine)

        try #require(second.canMoveTerminalHere(for: conversation))
        second.moveTerminalHere(for: conversation)

        #expect(first.terminalSessions.isEmpty)
        let movedTab = try #require(second.runningTerminal(for: conversation))
        #expect(movedTab.engine == engine)
        #expect(engine.draws(movedTab.terminalView))
    }

    /// The tab never starts, so nothing connects to the host; a stand-in answers that the host's tmux runs its CLI.
    @Test(arguments: TerminalEngine.allCases)
    func anSSHTabKeepsItsEngineInItsNewWindow(_ engine: TerminalEngine) async throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: engine)
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation(host: .ssh("devbox"))
        let first = sandbox.makeStore(listing: [conversation])
        let second = sandbox.makeStore(listing: [conversation])
        first.launch(conversation, action: .resume)
        first.selectTerminal(nil)
        try #require(first.runningTerminal(for: conversation)?.engine == engine)
        sandbox.engineStore.setEngine(engine.otherEngine)

        try #require(second.canMoveTerminalHere(for: conversation))
        second.moveTerminalHere(for: conversation, remoteRunner: RemoteCommandRecorder().runner(answering: (0, "")))

        try await expectEventually { second.runningTerminal(for: conversation) != nil }
        #expect(first.terminalSessions.isEmpty)
        let movedTab = try #require(second.runningTerminal(for: conversation))
        #expect(movedTab.engine == engine)
        #expect(engine.draws(movedTab.terminalView))
    }

    /// Runs the installed tmux in a sandbox server; see `ThisMacTmuxSandbox`. The moved tab reattaches to the same CLI,
    /// drawn by the same engine.
    @Test(arguments: TerminalEngine.allCases)
    func aTabWhoseCLIRunsInTmuxKeepsItsEngineInItsNewWindow(_ engine: TerminalEngine) async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        try sandbox.writeExecutable(named: "claude", script: "#!/bin/sh\nexec /bin/sleep 60\n")
        let conversation = Conversation.fixture(projectPath: sandbox.project.path)
        let windowRegistry = WorkspaceWindowRegistry()
        let engineStore = TerminalEngineStore(userDefaults: settings.userDefaults)
        engineStore.setEngine(engine)
        let makeStore = {
            ConversationStore(
                adapters: [StaticConversationAdapter(discoveredConversations: [conversation])],
                commandResolver: sandbox.resolver,
                userDefaults: settings.userDefaults,
                sessionNotifier: RecordingSessionNotifier(),
                windowRegistry: windowRegistry,
                terminalEngineStore: engineStore,
                startsBackgroundPolling: false
            )
        }
        let first = makeStore()
        let second = makeStore()
        defer {
            first.closeAllTerminals()
            second.closeAllTerminals()
        }
        // Tabs run the CLI directly until a refresh has checked the tmux version.
        for store in [first, second] {
            store.refreshThisMac()
            #expect(await sandbox.waitUntil { !store.isScanningThisMac })
        }
        let tmuxSessionName = TmuxSessionName.forConversation(conversation)
        first.launch(conversation, action: .resume)
        let tab = try #require(first.runningTerminal(for: conversation))
        tab.startIfNeeded()
        try #require(await sandbox.waitUntil { sandbox.server.sessionNames() == [tmuxSessionName] }, "\(sandbox.launchDiagnostics(for: tab))")
        try #require(await sandbox.waitForPaneProcess(in: first, for: tab))
        let cliProcessID = try #require(tab.tmuxPaneProcessID)
        engineStore.setEngine(engine.otherEngine)

        try #require(second.canMoveTerminalHere(for: conversation))
        second.moveTerminalHere(for: conversation)

        let movedTab = try #require(second.runningTerminal(for: conversation))
        #expect(movedTab.engine == engine)
        #expect(engine.draws(movedTab.terminalView))
        movedTab.startIfNeeded()
        #expect(await sandbox.waitForPaneProcess(in: second, for: movedTab), "\(sandbox.launchDiagnostics(for: movedTab))")
        #expect(movedTab.tmuxPaneProcessID == cliProcessID)
    }
}
