import Foundation
import Testing

@testable import JustSessions

/// Tabs that go because their session is deleted, they move to another window, or their host disconnects were not
/// closed by you, so Reopen Closed Tab doesn't bring them back.
@MainActor
struct TabsGoneWithoutClosingTests {
    @Test func aTabClosedToDeleteItsSessionIsNotKept() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        _ = try #require(sandbox.openTab(of: sandbox.conversation, in: sandbox.first))

        sandbox.first.closeAndDelete(sandbox.conversation)

        #expect(sandbox.first.terminalSessions.isEmpty)
        #expect(!sandbox.first.canReopenClosedTab)
    }

    @Test func aTabMovedToAnotherWindowIsNotKeptWhereItWas() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let waitingTab = try #require(try sandbox.first.makeTerminal(for: sandbox.conversation, action: .resume, startsOnceShown: true))
        sandbox.first.insertReopenedTerminal(waitingTab, at: 0, selecting: false)

        sandbox.second.moveTerminalHere(for: sandbox.conversation)

        #expect(sandbox.first.terminalSessions.isEmpty)
        #expect(!sandbox.first.canReopenClosedTab)
        #expect(!sandbox.second.canReopenClosedTab)
    }

    @Test func aTabClosedByDisconnectingItsHostIsNotKept() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let conversation = sandbox.listSSHSession()
        for store in [sandbox.first, sandbox.second] { store.remoteHostList = RemoteHostList(hosts: ["devbox"]) }
        _ = try #require(sandbox.openTab(of: conversation, in: sandbox.first))

        sandbox.first.disconnectHost("devbox", endingTmuxSessions: false, connections: SSHLoginConnections(close: { _, _ in }))

        #expect(sandbox.first.terminalSessions.isEmpty)
        #expect(!sandbox.first.canReopenClosedTab)
    }
}
