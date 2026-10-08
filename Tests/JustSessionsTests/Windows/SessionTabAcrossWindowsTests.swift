import Foundation
import Testing
@testable import JustSessions

/// A session runs in at most one tab across the app's windows: opening it where another window has its tab shows that
/// tab instead of a second tab on the same CLI.
@MainActor
struct SessionTabAcrossWindowsTests {
    @Test func resumingASessionWhoseTabIsInAnotherWindowShowsThatTab() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let tab = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.first))

        sandbox.second.launch(sandbox.conversation, action: .resume)

        #expect(sandbox.second.terminalSessions.isEmpty)
        #expect(sandbox.first.terminalSessions.map(\.id) == [tab.id])
        #expect(sandbox.first.selectedTerminalID == tab.id)
    }

    /// Even with the CLI listed in tmux, which a click would otherwise reattach to in a new tab.
    @Test func clickingASessionWhoseTabIsInAnotherWindowLeavesItToThePreview() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        _ = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.first))
        sandbox.second.setTmuxSessionNames([TmuxSessionName.forConversation(sandbox.conversation)], on: .thisMac)

        #expect(!sandbox.second.showRunningCLI(for: sandbox.conversation))

        #expect(sandbox.second.terminalSessions.isEmpty)
        // A click only looks; the other window stays as it was.
        #expect(sandbox.first.selectedTerminalID == nil)
    }

    @Test func aTabWhoseCLIEndedInAnotherWindowLeavesTheSessionToResumeHere() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let endedTab = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.first))
        endedTab.processFinished(exitCode: 0)

        sandbox.second.launch(sandbox.conversation, action: .resume)

        #expect(sandbox.second.runningTerminal(for: sandbox.conversation) != nil)
        #expect(sandbox.first.selectedTerminalID == nil)
    }

    @Test func closingTheOtherWindowLeavesItsSessionsToResumeHere() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        _ = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.first))

        sandbox.first.closeWorkspace()
        sandbox.second.launch(sandbox.conversation, action: .resume)

        #expect(sandbox.second.runningTerminal(for: sandbox.conversation) != nil)
    }

    @Test func resumingSeveralSessionsLeavesThoseInOtherWindowsThere() throws {
        let sandbox = try TwoWindowSandbox(sessionCount: 2)
        defer { sandbox.tearDown() }
        let inFirstWindow = sandbox.conversations[0]
        let notOpen = sandbox.conversations[1]
        _ = try #require(sandbox.openTab(of: inFirstWindow, in: sandbox.first))

        sandbox.second.launch([inFirstWindow, notOpen], action: .resume)

        #expect(sandbox.second.terminalSessions.compactMap(\.conversation?.id) == [notOpen.id])
        #expect(sandbox.first.selectedTerminalID == nil)
    }

    @Test func resumingOnlySessionsInOtherWindowsShowsTheLastThere() throws {
        let sandbox = try TwoWindowSandbox(sessionCount: 2)
        defer { sandbox.tearDown() }
        _ = try #require(sandbox.openTab(of: sandbox.conversations[0], in: sandbox.first))
        let last = try #require(sandbox.openTab(of: sandbox.conversations[1], in: sandbox.first))

        sandbox.second.launch(sandbox.conversations, action: .resume)

        #expect(sandbox.second.terminalSessions.isEmpty)
        #expect(sandbox.first.selectedTerminalID == last.id)
    }

    /// Reopening the tabs from the last quit waits for the host's sessions. A session opened meanwhile in another
    /// window keeps its tab there.
    @Test func aTabFromTheLastQuitStaysClosedWhileAnotherWindowHasItsSession() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        sandbox.second.beginReopening([.session(sandbox.conversation, wasSelected: true)])
        _ = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.first))

        sandbox.second.replaceConversations(on: .thisMac, with: sandbox.conversations)

        #expect(sandbox.second.terminalSessions.isEmpty)
        #expect(sandbox.second.pendingTabReopening.waitingTabs.isEmpty)
    }

    @Test func storesMadeOnTheirOwnSeeNoOtherWindow() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        _ = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.first))
        let alone = ConversationStore(adapters: [], sessionNotifier: RecordingSessionNotifier(), startsBackgroundPolling: false)

        #expect(alone.runningTerminalInAnotherWindow(for: sandbox.conversation) == nil)
        #expect(sandbox.second.runningTerminalInAnotherWindow(for: sandbox.conversation) != nil)
    }
}
