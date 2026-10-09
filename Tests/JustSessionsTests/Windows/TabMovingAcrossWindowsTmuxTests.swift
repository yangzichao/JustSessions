import Darwin
import Foundation
import Testing
@testable import JustSessions

/// Runs the installed tmux in a sandbox server; see `ThisMacTmuxSandbox`.
@MainActor
struct TabMovingAcrossWindowsTmuxTests {
    @Test func aMovedTabReattachesToTheSameCLIInItsNewWindow() async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        try sandbox.writeExecutable(named: "claude", script: "#!/bin/sh\nexec /bin/sleep 60\n")
        let conversation = Conversation(
            provider: .claude,
            sessionID: UUID().uuidString.lowercased(),
            projectPath: sandbox.project.path,
            suggestedTitle: "Paper",
            updatedAt: .now,
            sourceFile: sandbox.root.appendingPathComponent("session.jsonl")
        )
        let windowRegistry = WorkspaceWindowRegistry()
        let makeStore = {
            ConversationStore(
                adapters: [StaticConversationAdapter(discoveredConversations: [conversation])],
                commandResolver: sandbox.resolver,
                sessionNotifier: RecordingSessionNotifier(),
                windowRegistry: windowRegistry,
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

        #expect(second.canMoveTerminalHere(for: conversation))
        second.moveTerminalHere(for: conversation)

        #expect(first.terminalSessions.isEmpty)
        let movedTab = try #require(second.runningTerminal(for: conversation))
        #expect(second.selectedTerminalID == movedTab.id)
        movedTab.startIfNeeded()
        // The first window's client has gone, and the moved tab's is the only one attached.
        #expect(await sandbox.waitUntil {
            sandbox.tmuxOutput(["list-clients", "-F", "#{client_pid}"]).trimmingCharacters(in: .whitespacesAndNewlines)
                == "\(movedTab.processID)"
        }, "\(sandbox.launchDiagnostics(for: movedTab))")
        #expect(await sandbox.waitForPaneProcess(in: second, for: movedTab))
        #expect(movedTab.tmuxPaneProcessID == cliProcessID)
        #expect(sandbox.server.paneProcessIDsBySessionName() == [tmuxSessionName: cliProcessID])
        #expect(kill(cliProcessID, 0) == 0)
    }
}
