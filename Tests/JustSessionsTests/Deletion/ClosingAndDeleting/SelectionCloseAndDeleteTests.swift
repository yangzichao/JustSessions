import Foundation
import Testing

@testable import JustSessions

/// Deleting a multi-selection closes and ends the selected sessions that run, as Close and delete does for one, then
/// deletes the whole selection.
@MainActor
struct SelectionCloseAndDeleteTests {
    @Test func runningSessionsHaveTheirCLIsEndedAndTheWholeSelectionIsDeleted() async throws {
        let sandbox = try TwoWindowSandbox(sessionCount: 3)
        defer { sandbox.tearDown() }
        let (inOtherWindow, inTmux) = (sandbox.conversations[0], sandbox.conversations[1])
        let store = sandbox.first
        _ = try #require(sandbox.openTab(of: inOtherWindow, in: sandbox.second))
        store.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(inTmux)]

        store.closeAndDeleteConversations(sandbox.conversations)

        #expect(sandbox.second.terminalSessions.isEmpty)
        #expect(!store.isRunningInTmux(inTmux))
        try await expectEventually { store.conversations.isEmpty }
        #expect(store.alert == nil)
    }

    @Test func thePlanCountsTheSessionsWhoseCLIsEndFirst() throws {
        let sandbox = try TwoWindowSandbox(sessionCount: 3)
        defer { sandbox.tearDown() }
        let store = sandbox.first
        _ = try #require(sandbox.openTab(of: sandbox.conversations[0], in: store))
        store.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(sandbox.conversations[1])]

        let closingPlan = store.deletionPlan(for: sandbox.conversations, endingTheirCLIs: true)
        let skippingPlan = store.deletionPlan(for: sandbox.conversations)

        #expect(closingPlan.deletableConversations.count == 3)
        #expect(closingPlan.cliEndingCount == 2)
        #expect(closingPlan.openTerminalCount == 0)
        #expect(skippingPlan.deletableConversations.count == 1)
        #expect(skippingPlan.cliEndingCount == 0)
        #expect(skippingPlan.openTerminalCount == 2)
    }
}
