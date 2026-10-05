import Foundation
import Testing
@testable import JustSessions

/// Sessions asked to be deleted while a deletion runs join it: it goes on to them after the others, with one
/// progress bar and one report.
@MainActor
struct DeletionJoiningTests {
    @Test func sessionsAskedForWhileADeletionRunsShareItsProgressAndReport() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        // Newest first, the order deletion goes in.
        let onDevbox = try (0..<3).map {
            try sandbox.savedConversation(onHost: "devbox", updatedAt: Date.now.addingTimeInterval(-Double($0) * 60))
        }
        let refused = try sandbox.savedConversation(title: "Keep me", updatedAt: Date.now.addingTimeInterval(-3_600))
        let refusingAdapter = FileBackedConversationAdapter(
            provider: .claude,
            conversations: [refused],
            refusedSessionIDs: [refused.sessionID],
            refusalReason: "Permission denied"
        )
        let hosts = SimulatedSSHHosts(holdingAttempt: 1) { _, _ in SimulatedSSHHosts.deleted }
        let store = sandbox.makeStore(listing: onDevbox + [refused], adapters: [refusingAdapter], remoteDeletion: hosts.deletion)

        store.deleteConversations(Array(onDevbox.prefix(2)))
        try await expectEventually { hosts.totalAttempts == 1 }
        store.deleteConversations([onDevbox[2], refused])
        #expect(store.pendingDeletionConversationIDs == Set((onDevbox + [refused]).map(\.id)))
        #expect(store.deletionProgress.totalCount == 4)
        hosts.releaseHeldAttempt()
        try await expectEventually { !store.isDeletingSessions }

        #expect(hosts.attempts(on: "devbox") == 3)
        #expect(store.conversations.map(\.id) == [refused.id])
        #expect(store.alert?.title == "1 session wasn't deleted")
        #expect(store.errorMessage == """
            Deleted 3 of 4 sessions. The other one is still listed.

            Claude Code · Keep me: Permission denied.
            """)
        #expect(store.deletionProgress.totalCount == 0)
    }

    @Test func aHostGivenUpOnIsNotTriedAgainForSessionsThatJoined() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let onDevbox = try (0..<2).map {
            try sandbox.savedConversation(onHost: "devbox", updatedAt: Date.now.addingTimeInterval(-Double($0) * 60))
        }
        let hosts = SimulatedSSHHosts(holdingAttempt: 1) { _, _ in SimulatedSSHHosts.connectionFailure }
        let store = sandbox.makeStore(listing: onDevbox, remoteDeletion: hosts.deletion)

        store.delete(onDevbox[0])
        try await expectEventually { hosts.totalAttempts == 1 }
        store.delete(onDevbox[1])
        hosts.releaseHeldAttempt()
        try await expectEventually { !store.isDeletingSessions }

        #expect(hosts.attempts(on: "devbox") == 1)
        #expect(store.conversations.count == 2)
        #expect(store.alert?.title == "2 sessions weren't deleted")
        #expect(store.alert?.retryConversationIDs == Set(onDevbox.map(\.id)))
    }

    /// Cancel drops the sessions that joined; those asked for after Cancel wait for the deletion to stop, then
    /// start on their own.
    @Test func cancelDropsTheSessionsThatJoinedAndLaterOnesStartAfterIt() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let sessions = try (0..<4).map {
            try sandbox.savedConversation(onHost: "devbox", updatedAt: Date.now.addingTimeInterval(-Double($0) * 60))
        }
        let hosts = SimulatedSSHHosts(holdingAttempt: 1) { _, _ in SimulatedSSHHosts.deleted }
        let store = sandbox.makeStore(listing: sessions, remoteDeletion: hosts.deletion)

        store.deleteConversations(Array(sessions[0...1]))
        try await expectEventually { hosts.totalAttempts == 1 }
        store.deleteConversations([sessions[2]])
        store.cancelDeletion()
        store.deleteConversations([sessions[3]])
        #expect(store.queuedDeletionConversationIDs == [sessions[3].id])
        #expect(store.deletionProgress.totalCount == 3)
        hosts.releaseHeldAttempt()
        try await expectEventually { !store.isDeletingSessions && store.queuedDeletionConversationIDs.isEmpty }

        #expect(hosts.totalAttempts == 2)
        #expect(store.conversations.map(\.id) == [sessions[1].id, sessions[2].id])
        #expect(store.errorMessage == nil)
    }

    @Test func archivingSelectedProjectsDeletesTheirSessionsAndArchivesEvenOneWithOnlyARunningSession() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let firstProject = Self.project("first", in: sandbox)
        let runningOnlyProject = Self.project("running-only", in: sandbox)
        let otherProject = Self.project("other", in: sandbox)
        let deleted = try Self.savedConversation(in: firstProject, sandbox: sandbox)
        let running = try Self.savedConversation(in: runningOnlyProject, sandbox: sandbox)
        let kept = try Self.savedConversation(in: otherProject, sandbox: sandbox)
        let store = sandbox.makeStore(listing: [deleted, running, kept])
        store.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(running)]

        let selectedProjects: Set<String> = [firstProject.path, runningOnlyProject.path]
        #expect(store.deletionPlan(forProjects: selectedProjects).deletableConversations.map(\.id) == [deleted.id])
        store.deleteSessionsAndRemoveProjects(selectedProjects)
        #expect(store.sidebarProjectGroups.map(\.id) == [otherProject.path])
        try await expectEventually { !store.isDeletingSessions }

        #expect(!sandbox.fileExists(for: deleted))
        #expect(sandbox.fileExists(for: running) && sandbox.fileExists(for: kept))
        #expect(Set(store.archivedProjectPaths) == selectedProjects)
    }

    private static func project(_ name: String, in sandbox: DeletionSandbox) -> URL {
        sandbox.directory.appendingPathComponent(name)
    }

    private static func savedConversation(in project: URL, sandbox: DeletionSandbox) throws -> Conversation {
        let conversation = try sandbox.savedConversation()
        return .fixture(
            sessionID: conversation.sessionID,
            projectPath: project.path,
            sourceFile: conversation.sourceFile
        )
    }
}
