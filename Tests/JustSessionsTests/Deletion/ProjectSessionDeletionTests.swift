import Foundation
import Testing
@testable import JustSessions

struct ProjectSessionDeletionTests {
    @Test @MainActor func batchDeletionKeepsOtherProjectsAndUnsupportedSessions() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let selectedProject = try makeProject("selected", in: temporaryDirectory)
        let otherProject = try makeProject("other", in: temporaryDirectory)

        let selectedClaude = try savedConversation(.claude, project: selectedProject, in: temporaryDirectory)
        let selectedCodex = try savedConversation(.codex, project: selectedProject, in: temporaryDirectory)
        let selectedAntigravity = try savedConversation(.antigravity, project: selectedProject, in: temporaryDirectory)
        let otherClaude = try savedConversation(.claude, project: otherProject, in: temporaryDirectory)
        let store = makeStore(
            listing: [selectedClaude, selectedCodex, selectedAntigravity, otherClaude],
            userDefaults: isolatedUserDefaults.userDefaults
        )

        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }
        let deletionPlan = store.deletionPlan(for: selectedProject.path)
        #expect(deletionPlan.deletableConversations.map(\.id).sorted() == [selectedClaude.id, selectedCodex.id].sorted())
        #expect(deletionPlan.unsupportedCount == 1)

        store.deleteSessions(in: selectedProject.path)
        try await expectEventually { !store.isDeletingSessions }
        #expect(!FileManager.default.fileExists(atPath: selectedClaude.sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: selectedCodex.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: selectedAntigravity.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: otherClaude.sourceFile.path))
        #expect(store.conversations.map(\.id).sorted() == [selectedAntigravity.id, otherClaude.id].sorted())
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor func selectedSessionDeletionSpansProjectsAndSkipsUnsupportedSessions() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let firstProject = try makeProject("first", in: temporaryDirectory)
        let secondProject = try makeProject("second", in: temporaryDirectory)

        let selectedFirstClaude = try savedConversation(.claude, project: firstProject, in: temporaryDirectory)
        let unselectedFirstClaude = try savedConversation(.claude, project: firstProject, in: temporaryDirectory)
        let selectedSecondCodex = try savedConversation(.codex, project: secondProject, in: temporaryDirectory)
        let selectedAntigravity = try savedConversation(.antigravity, project: secondProject, in: temporaryDirectory)
        let store = makeStore(
            listing: [selectedFirstClaude, unselectedFirstClaude, selectedSecondCodex, selectedAntigravity],
            userDefaults: isolatedUserDefaults.userDefaults
        )

        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }
        let selectedConversations = [selectedFirstClaude, selectedSecondCodex, selectedAntigravity]
        let deletionPlan = store.deletionPlan(for: selectedConversations)
        #expect(deletionPlan.deletableConversations.map(\.id).sorted() == [selectedFirstClaude.id, selectedSecondCodex.id].sorted())
        #expect(deletionPlan.unsupportedCount == 1)

        store.deleteConversations(selectedConversations)
        #expect(store.isDeletionPending(for: selectedFirstClaude))
        #expect(!store.isDeletionPending(for: unselectedFirstClaude))
        try await expectEventually { !store.isDeletingSessions }
        #expect(!FileManager.default.fileExists(atPath: selectedFirstClaude.sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: selectedSecondCodex.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: selectedAntigravity.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: unselectedFirstClaude.sourceFile.path))
        #expect(store.conversations.map(\.id).sorted() == [selectedAntigravity.id, unselectedFirstClaude.id].sorted())
        #expect(store.errorMessage == nil)
    }

    private func makeProject(_ name: String, in temporaryDirectory: URL) throws -> URL {
        let project = temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        return project
    }

    private func savedConversation(_ provider: ConversationProvider, project: URL, in temporaryDirectory: URL) throws -> Conversation {
        let sessionID = UUID().uuidString
        let sourceFile = temporaryDirectory.appendingPathComponent("\(sessionID).jsonl")
        try "session".write(to: sourceFile, atomically: true, encoding: .utf8)
        return .fixture(provider: provider, sessionID: sessionID, projectPath: project.path, title: sessionID, sourceFile: sourceFile)
    }

    @MainActor private func makeStore(listing conversations: [Conversation], userDefaults: UserDefaults) -> ConversationStore {
        ConversationStore(
            adapters: ConversationProvider.allCases.map {
                FileBackedConversationAdapter(provider: $0, conversations: conversations)
            },
            userDefaults: userDefaults
        )
    }
}
