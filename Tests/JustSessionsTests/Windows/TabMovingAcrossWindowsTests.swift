import Foundation
import Testing
@testable import JustSessions

/// Moving a session's tab to this window closes the other window's tab and opens the session here, only when that
/// leaves its CLI running.
@MainActor
struct TabMovingAcrossWindowsTests {
    /// The sandbox finds no tmux, so the CLI would end with its tab.
    @Test func aTabWhoseCLIRunsWithoutTmuxStaysInItsWindow() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let tab = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.first))
        #expect(tab.tmuxSessionName == nil)

        #expect(!sandbox.second.canMoveTerminalHere(for: sandbox.conversation))
        sandbox.second.moveTerminalHere(for: sandbox.conversation)

        #expect(sandbox.first.terminalSessions.map(\.id) == [tab.id])
        #expect(sandbox.second.terminalSessions.isEmpty)
    }

    @Test func aTabWaitingToBeShownMovesWithoutStartingItsCLIThere() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let waitingTab = try #require(try sandbox.first.makeTerminal(for: sandbox.conversation, action: .resume, startsOnceShown: true))
        // As a tab from the last quit that was not selected; selecting it would start it.
        sandbox.first.insertReopenedTerminal(waitingTab, at: 0, selecting: false)
        #expect(waitingTab.isWaitingToBeShown)

        #expect(sandbox.second.canMoveTerminalHere(for: sandbox.conversation))
        sandbox.second.moveTerminalHere(for: sandbox.conversation)

        #expect(sandbox.first.terminalSessions.isEmpty)
        #expect(waitingTab.isWaitingToBeShown)
        let movedTab = try #require(sandbox.second.runningTerminal(for: sandbox.conversation))
        #expect(movedTab.isRunning)
        #expect(sandbox.second.selectedTerminalID == movedTab.id)
    }

    @Test func anSSHTabMovesOnceTheHostConfirmsTmuxRunsItsCLI() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let conversation = sandbox.listSSHSession()
        let tab = try #require(sandbox.openTab(of: conversation, in: sandbox.first))
        let tmuxSessionName = TmuxSessionName.forConversation(conversation)
        #expect(tab.tmuxSessionName == tmuxSessionName)
        let recorder = RemoteCommandRecorder()

        #expect(sandbox.second.canMoveTerminalHere(for: conversation))
        sandbox.second.moveTerminalHere(for: conversation, remoteRunner: recorder.runner(answering: (0, "")))

        try await expectEventually { sandbox.second.runningTerminal(for: conversation) != nil }
        #expect(sandbox.first.terminalSessions.isEmpty)
        // Closed there the way Keep running closes a tab.
        #expect(sandbox.first.isRunningInTmux(conversation))
        #expect(recorder.commands.map(\.host) == ["devbox"])
        #expect(recorder.commands.first?.command == RemoteTmuxCommands.hasSessionCommand(tmuxSessionName, on: "devbox"))
        let movedTab = try #require(sandbox.second.runningTerminal(for: conversation))
        #expect(movedTab.tmuxSessionName == tmuxSessionName)
        #expect(sandbox.second.selectedTerminalID == movedTab.id)
    }

    /// The host may lack tmux, where an SSH tab's CLI runs directly, or may not answer.
    @Test func anSSHTabStaysInItsWindowWhenTheHostDoesNotConfirmTmux() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let conversation = sandbox.listSSHSession()
        let tab = try #require(sandbox.openTab(of: conversation, in: sandbox.first))

        sandbox.second.moveTerminalHere(for: conversation, remoteRunner: RemoteCommandRecorder().runner(answering: (1, "")))

        try await expectEventually { sandbox.second.errorMessage != nil }
        #expect(sandbox.first.terminalSessions.map(\.id) == [tab.id])
        #expect(sandbox.second.terminalSessions.isEmpty)
    }
}
