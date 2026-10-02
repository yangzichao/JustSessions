import Foundation
import Testing
@testable import JustSessions

@MainActor
struct PiStoreDeletionTests {
    @Test func piSessionsAreDeletedUnlessTheirCLIIsStillRunning() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let deleted = try sandbox.savedConversation(.pi, title: "Delete me")
        let running = try sandbox.savedConversation(.pi, title: "Still running")
        let store = sandbox.makeStore(listing: [deleted, running])
        store.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(running)]

        let deletionPlan = store.deletionPlan(for: [deleted, running])
        #expect(deletionPlan.deletableConversations.map(\.id) == [deleted.id])
        #expect(deletionPlan.openTerminalCount == 1)
        #expect(deletionPlan.unsupportedCount == 0)
        store.deleteConversations([deleted, running])
        try await expectEventually { !store.isDeletingSessions }

        #expect(!sandbox.fileExists(for: deleted))
        #expect(sandbox.fileExists(for: running))
        #expect(store.conversations.map(\.id) == [running.id])
        #expect(store.errorMessage == nil)
    }
}
