import Testing

@testable import JustSessions

/// Views that read tabs through the store follow a tab's own state through `tabStateRevision`: every open tab's own
/// change counts, a closed tab's no longer does, and selecting a tab changes nothing there.
@MainActor
struct TabStateRevisionTests {
    @Test func aTabsOwnChangesCountButSelectingATabDoesNot() async throws {
        let sandbox = try TwoWindowSandbox(sessionCount: 2)
        defer { sandbox.tearDown() }
        let store = sandbox.first
        let firstTab = try #require(sandbox.openTab(of: sandbox.conversations[0], in: store))
        let secondTab = try #require(sandbox.openTab(of: sandbox.conversations[1], in: store))
        let revisions = StoreChangeCounter(store) { _ = $0.tabStateRevision }
        defer { revisions.cancel() }

        store.selectTerminal(firstTab.id)
        await settle()
        store.selectTerminal(secondTab.id)
        await settle()
        #expect(revisions.count == 0)

        firstTab.updateCLIActivity(.needsInput(reason: nil))
        await settle()
        #expect(revisions.count == 1)
        firstTab.updateCLIActivity(.needsInput(reason: nil))
        await settle()
        #expect(revisions.count == 1)

        store.closeTerminal(secondTab.id)
        await settle()
        let countAfterClosing = revisions.count
        secondTab.updateDisplayTitle("Renamed after closing")
        await settle()
        #expect(revisions.count == countAfterClosing)
    }

    /// Lets the counter look again, as it does on the main actor's next turn.
    private func settle() async {
        for _ in 0..<5 { await Task.yield() }
    }
}
