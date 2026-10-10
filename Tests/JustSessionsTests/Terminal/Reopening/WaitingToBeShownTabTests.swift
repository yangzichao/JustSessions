import Foundation
import Testing
@testable import JustSessions

/// A reopened tab whose CLI no longer ran starts nothing until you select it, and until then counts as nothing running.
@MainActor
struct WaitingToBeShownTabTests {
    @Test func runsNothingAndCountsAsNotRunningUntilSelected() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let conversation = sandbox.conversation()
        store.replaceConversations(on: .thisMac, with: [conversation])

        let tab = try #require(try store.makeTerminal(for: conversation, action: .resume, startsOnceShown: true))
        store.insertReopenedTerminal(tab, at: 0, selecting: false)
        tab.startIfNeeded()

        #expect(tab.isWaitingToBeShown)
        #expect(tab.processID == 0)
        #expect(!tab.isRunning)
        #expect(tab.runStatus == .waitingToBeShown)
        #expect(tab.cliActivity == nil)
        #expect(store.activitySummary(forProjectDirectoryKey: conversation.projectDirectoryKey).runningCount == 0)
        // Clicking its session shows the tab instead of opening another.
        #expect(store.runningTerminal(for: conversation)?.id == tab.id)
    }

    @Test func selectingItStartsIt() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let conversation = sandbox.conversation()
        store.replaceConversations(on: .thisMac, with: [conversation])
        let tab = try #require(try store.makeTerminal(for: conversation, action: .resume, startsOnceShown: true))
        store.insertReopenedTerminal(tab, at: 0, selecting: false)

        #expect(store.showRunningCLI(for: conversation))

        #expect(store.selectedTerminalID == tab.id)
        #expect(!tab.isWaitingToBeShown)
        #expect(tab.isRunning)
        #expect(tab.processID > 0)
        #expect(tab.runStatus == .running(nil))
    }

    @Test func closingItLeavesNoTmuxSessionBehind() throws {
        let sandbox = try TabReopeningSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let conversation = sandbox.conversation()
        let tmuxSessionName = TmuxSessionName.forConversation(conversation)
        let tab = TerminalSession(
            engine: .swiftTerm,
            conversation: conversation,
            provider: .claude,
            projectPath: conversation.projectPath,
            action: .resume,
            displayTitle: "Session",
            command: NativeCLICommand(executablePath: "/bin/sh", arguments: [], workingDirectory: sandbox.project.path, environment: []),
            tmuxSessionName: tmuxSessionName,
            startsOnceShown: true
        )
        store.insertReopenedTerminal(tab, at: 0, selecting: false)

        #expect(!tab.canKeepCLIRunningAfterClose)
        store.closeTerminal(tab.id, endingTmuxSession: false)

        #expect(store.terminalSessions.isEmpty)
        #expect(store.tmuxSessionNamesByHost[.thisMac]?.contains(tmuxSessionName) != true)
    }
}
