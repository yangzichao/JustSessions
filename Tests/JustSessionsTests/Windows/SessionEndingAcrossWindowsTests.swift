import Foundation
import Testing

@testable import JustSessions

/// End session, from a session's row, stops its CLI wherever it runs: in a tab of either window, or in tmux with no
/// tab open.
@MainActor
struct SessionEndingAcrossWindowsTests {
    @Test func endingASessionClosesItsTabInAnotherWindow() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        _ = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.first))
        #expect(sandbox.second.canEndSession(sandbox.conversation))

        sandbox.second.endSession(sandbox.conversation)

        #expect(sandbox.first.terminalSessions.isEmpty)
        #expect(!sandbox.first.canEndSession(sandbox.conversation))
        #expect(!sandbox.second.canEndSession(sandbox.conversation))
    }

    /// Both windows list the tmux session, and neither does once it has ended.
    @Test func endingASessionRunningInTmuxWithoutATabForgetsItInEveryWindow() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let tmuxSessionName = TmuxSessionName.forConversation(sandbox.conversation)
        for store in [sandbox.first, sandbox.second] { store.setTmuxSessionNames([tmuxSessionName], on: .thisMac) }
        #expect(sandbox.second.canEndSession(sandbox.conversation))

        sandbox.second.endSession(sandbox.conversation)

        #expect(!sandbox.first.isRunningInTmux(sandbox.conversation))
        #expect(!sandbox.second.isRunningInTmux(sandbox.conversation))
    }

    /// Ending a multi-selection ends the sessions that run, in a tab of either window or in tmux, and skips the rest.
    @Test func endingSelectedSessionsEndsEachOneThatRuns() throws {
        let sandbox = try TwoWindowSandbox(sessionCount: 4)
        let (inFirstWindow, inSecondWindow, inTmux, notRunning) =
            (sandbox.conversations[0], sandbox.conversations[1], sandbox.conversations[2], sandbox.conversations[3])
        defer { sandbox.tearDown() }
        _ = try #require(sandbox.openTab(of: inFirstWindow, in: sandbox.first))
        _ = try #require(sandbox.openTab(of: inSecondWindow, in: sandbox.second))
        let tmuxSessionName = TmuxSessionName.forConversation(inTmux)
        for store in [sandbox.first, sandbox.second] { store.setTmuxSessionNames([tmuxSessionName], on: .thisMac) }
        #expect(sandbox.second.canEndSession(inTmux))
        #expect(!sandbox.second.canEndSession(notRunning))

        sandbox.second.endSessions(sandbox.conversations)

        #expect(sandbox.first.terminalSessions.isEmpty)
        #expect(sandbox.second.terminalSessions.isEmpty)
        for store in [sandbox.first, sandbox.second] {
            #expect(!store.isRunningInTmux(inTmux))
            #expect(!sandbox.conversations.contains(where: store.canEndSession))
        }
    }

    @Test func aSessionNothingRunsCannotBeEnded() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let endedTab = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.first))
        endedTab.processFinished(exitCode: 0)

        #expect(!sandbox.first.canEndSession(sandbox.conversation))
        #expect(!sandbox.second.canEndSession(sandbox.conversation))
    }
}
