import Combine
import Foundation
import Testing
@testable import JustSessions

/// Deleting many sessions at once: SSH hosts that cannot be reached, Cancel, and how often the list changes.
@MainActor
struct BulkSessionDeletionTests {
    @Test func anUnreachableHostIsTriedOnceAndItsSessionsStayListed() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let sessions = try (0..<150).map { try sandbox.savedConversation(onHost: "devbox", title: "Session \($0)") }
        let hosts = SimulatedSSHHosts { _, _ in SimulatedSSHHosts.connectionFailure }
        let store = sandbox.makeStore(listing: sessions, remoteDeletion: hosts.deletion)

        store.deleteConversations(sessions)
        try await expectEventually { !store.isDeletingSessions }

        #expect(hosts.attempts(on: "devbox") == 1)
        #expect(store.conversations.count == 150)
        #expect(store.errorMessage == """
            Some sessions could not be deleted:
            devbox could not be reached, so 150 sessions on it were not deleted.
            """)
        #expect(store.canStartDeletion(of: sessions))
        #expect(!store.deferRefreshWhileDeleting(on: .ssh("devbox")))
        #expect(!sessions.contains { store.isDeletionPending(for: $0) })
    }

    @Test func aConnectionThatDropsPartwaySkipsTheRestOfThatHostOnly() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        // Newest first, the order deletion goes in: devbox, buildbox, and this Mac take turns.
        var onDevbox: [Conversation] = []
        var onBuildbox: [Conversation] = []
        var onThisMac: [Conversation] = []
        for index in 0..<6 {
            let updatedAt = Date.now.addingTimeInterval(-Double(index) * 600)
            onDevbox.append(try sandbox.savedConversation(onHost: "devbox", updatedAt: updatedAt))
            onBuildbox.append(try sandbox.savedConversation(onHost: "buildbox", updatedAt: updatedAt.addingTimeInterval(-60)))
            onThisMac.append(try sandbox.savedConversation(updatedAt: updatedAt.addingTimeInterval(-120)))
        }
        // devbox deletes three sessions, then its connection drops.
        let hosts = SimulatedSSHHosts { host, attempt in
            host == "devbox" && attempt > 3 ? SimulatedSSHHosts.connectionFailure : SimulatedSSHHosts.deleted
        }
        let store = sandbox.makeStore(listing: onDevbox + onBuildbox + onThisMac, remoteDeletion: hosts.deletion)

        store.deleteConversations(onDevbox + onBuildbox + onThisMac)
        try await expectEventually { !store.isDeletingSessions }

        #expect(hosts.attempts(on: "devbox") == 4)
        #expect(hosts.attempts(on: "buildbox") == 6)
        #expect(Set(store.conversations.map(\.id)) == Set(onDevbox.dropFirst(3).map(\.id)))
        #expect(!onThisMac.contains { sandbox.fileExists(for: $0) })
        #expect(store.errorMessage == """
            Some sessions could not be deleted:
            devbox could not be reached, so 3 sessions on it were not deleted.
            """)
    }

    /// A host that answers too slowly may still be reachable, so the message says it did not respond in time.
    @Test func aHostThatDoesNotRespondInTimeIsTriedOnceAndReportedAsSuch() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let sessions = try (0..<3).map {
            try sandbox.savedConversation(onHost: "devbox", updatedAt: Date.now.addingTimeInterval(-Double($0) * 60))
        }
        let hosts = SimulatedSSHHosts { _, _ in nil }
        let store = sandbox.makeStore(listing: sessions, remoteDeletion: hosts.deletion)

        store.deleteConversations(sessions)
        try await expectEventually { !store.isDeletingSessions }

        #expect(hosts.attempts(on: "devbox") == 1)
        #expect(store.conversations.count == 3)
        #expect(store.errorMessage == """
            Some sessions could not be deleted:
            devbox did not respond in time, so 3 sessions on it were not deleted.
            """)
    }

    /// The bar counts every session the deletion has dealt with, the skipped ones of an unreachable host included,
    /// and moving it does not change the store, so the sidebar is not drawn again for it.
    @Test func progressCountsEachSessionDealtWithWithoutChangingTheStore() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        // Newest first, the order deletion goes in: three on devbox, then two on buildbox.
        let onDevbox = try (0..<3).map {
            try sandbox.savedConversation(onHost: "devbox", updatedAt: Date.now.addingTimeInterval(-Double($0) * 60))
        }
        let onBuildbox = try (3..<5).map {
            try sandbox.savedConversation(onHost: "buildbox", updatedAt: Date.now.addingTimeInterval(-Double($0) * 60))
        }
        // devbox cannot be reached; the first buildbox deletion, the second tried overall, waits.
        let hosts = SimulatedSSHHosts(holdingAttempt: 2) { host, _ in
            host == "devbox" ? SimulatedSSHHosts.connectionFailure : SimulatedSSHHosts.deleted
        }
        let store = sandbox.makeStore(listing: onDevbox + onBuildbox, remoteDeletion: hosts.deletion)
        store.deletionListUpdateInterval = .zero

        store.deleteConversations(onDevbox + onBuildbox)
        #expect(store.deletionProgress.totalCount == 5)
        #expect(store.deletionProgress.completedCount == 0)
        var storeChangeCount = 0
        let storeChanges = store.objectWillChange.sink { _ in storeChangeCount += 1 }
        defer { storeChanges.cancel() }
        try await expectEventually { hosts.totalAttempts == 2 }

        #expect(store.deletionProgress.completedCount == 3)
        #expect(store.deletionProgress.totalCount == 5)
        #expect(storeChangeCount == 0)
        hosts.releaseHeldAttempt()
        try await expectEventually { !store.isDeletingSessions }

        #expect(store.deletionProgress.completedCount == 0)
        #expect(store.deletionProgress.totalCount == 0)
        #expect(Set(store.conversations.map(\.id)) == Set(onDevbox.map(\.id)))
    }

    @Test func cancelStopsAfterTheSessionBeingDeletedAndKeepsTheRest() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let sessions = try (0..<5).map {
            try sandbox.savedConversation(onHost: "devbox", updatedAt: Date.now.addingTimeInterval(-Double($0) * 60))
        }
        let hosts = SimulatedSSHHosts(holdingAttempt: 1) { _, _ in SimulatedSSHHosts.deleted }
        let store = sandbox.makeStore(listing: sessions, remoteDeletion: hosts.deletion)

        store.deleteConversations(sessions)
        try await expectEventually { hosts.totalAttempts == 1 }
        store.cancelDeletion()
        #expect(store.deletionProgress.isStopping)
        #expect(store.isDeletingSessions)
        hosts.releaseHeldAttempt()
        try await expectEventually { !store.isDeletingSessions }

        #expect(hosts.totalAttempts == 1)
        #expect(store.conversations.map(\.id) == sessions.dropFirst().map(\.id))
        #expect(store.errorMessage == nil)
        #expect(!store.deletionProgress.isStopping)
        #expect(store.canStartDeletion(of: sessions))

        // A later deletion starts as usual.
        store.deleteConversations([sessions[1]])
        try await expectEventually { !store.isDeletingSessions }
        #expect(hosts.totalAttempts == 2)
        #expect(store.conversations.map(\.id) == sessions.dropFirst(2).map(\.id))
    }

    @Test func aCanceledDeletionStillReportsFailuresFromBeforeCancel() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let refused = try sandbox.savedConversation(title: "Keep me", updatedAt: .now)
        let onDevbox = try (1...3).map {
            try sandbox.savedConversation(onHost: "devbox", updatedAt: Date.now.addingTimeInterval(-Double($0) * 60))
        }
        let refusingAdapter = FileBackedConversationAdapter(
            provider: .claude,
            conversations: [refused],
            refusedSessionIDs: [refused.sessionID],
            refusalReason: "Permission denied"
        )
        let hosts = SimulatedSSHHosts(holdingAttempt: 1) { _, _ in SimulatedSSHHosts.deleted }
        let store = sandbox.makeStore(listing: [refused] + onDevbox, adapters: [refusingAdapter], remoteDeletion: hosts.deletion)

        store.deleteConversations([refused] + onDevbox)
        try await expectEventually { hosts.totalAttempts == 1 }
        store.cancelDeletion()
        hosts.releaseHeldAttempt()
        try await expectEventually { !store.isDeletingSessions }

        #expect(hosts.totalAttempts == 1)
        #expect(store.conversations.map(\.id) == [refused.id] + onDevbox.dropFirst().map(\.id))
        #expect(store.errorMessage == "Some sessions could not be deleted:\nClaude Code · Keep me: Permission denied")
    }

    @Test func deletingManySessionsChangesTheStoreAFewTimesAndForgetsTheirTitlesAndPins() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let sessions = try (0..<2_000).map {
            try sandbox.savedConversation(title: "Session \($0)", updatedAt: Date.now.addingTimeInterval(-Double($0) * 60))
        }
        let deleted = Array(sessions.prefix(150))
        let kept = sessions[1_999]
        let store = sandbox.makeStore(listing: sessions)
        for conversation in [deleted[0], deleted[75], deleted[149], kept] {
            store.rename(conversation, to: "Custom \(conversation.suggestedTitle)")
            store.setPinned(true, conversation: conversation)
        }
        var storeChangeCount = 0
        let storeChanges = store.objectWillChange.sink { _ in storeChangeCount += 1 }
        defer { storeChanges.cancel() }

        store.deleteConversations(deleted)
        try await expectEventually { !store.isDeletingSessions }

        // One change to start, a few per group of deleted sessions, and one to end; not about three per session.
        #expect(storeChangeCount <= 20)
        #expect(store.conversations.count == 1_850)
        #expect(!deleted.contains { sandbox.fileExists(for: $0) })
        #expect(store.titleAliases.customTitlesByConversationID == [kept.id: "Custom Session 1999"])
        #expect(store.pinnedItems.pinnedConversationIDs == [kept.id])
        let savedTitles = ConversationTitleAliases.load(from: sandbox.userDefaults)
        let savedPins = PinnedItems.load(from: sandbox.userDefaults)
        #expect(savedTitles.customTitlesByConversationID == [kept.id: "Custom Session 1999"])
        #expect(savedPins.pinnedConversationIDs == [kept.id])
    }
}
