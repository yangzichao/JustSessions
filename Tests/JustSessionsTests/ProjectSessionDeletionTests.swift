import Foundation
import Testing
@testable import JustSessions

private struct TestDeletionAdapter: ConversationAdapter {
    let provider: ConversationProvider
    let discoveredConversations: [Conversation]

    func discover() throws -> [Conversation] { discoveredConversations }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] { [] }

    func delete(_ conversation: Conversation) throws {
        try FileManager.default.removeItem(at: conversation.sourceFile)
    }
}

struct ProjectSessionDeletionTests {
    @Test @MainActor func batchDeletionKeepsOtherProjectsAndUnsupportedSessions() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let selectedProject = temporaryDirectory.appendingPathComponent("selected")
        let otherProject = temporaryDirectory.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: selectedProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: otherProject, withIntermediateDirectories: true)

        func conversation(_ provider: ConversationProvider, project: URL) throws -> Conversation {
            let sessionID = UUID().uuidString
            let sourceFile = temporaryDirectory.appendingPathComponent("\(sessionID).jsonl")
            try "session".write(to: sourceFile, atomically: true, encoding: .utf8)
            return Conversation(
                provider: provider,
                sessionID: sessionID,
                projectPath: project.path,
                suggestedTitle: sessionID,
                updatedAt: .now,
                sourceFile: sourceFile
            )
        }

        let selectedClaude = try conversation(.claude, project: selectedProject)
        let selectedCodex = try conversation(.codex, project: selectedProject)
        let selectedAntigravity = try conversation(.antigravity, project: selectedProject)
        let otherClaude = try conversation(.claude, project: otherProject)
        let store = ConversationStore(adapters: [
            TestDeletionAdapter(provider: .claude, discoveredConversations: [selectedClaude, otherClaude]),
            TestDeletionAdapter(provider: .codex, discoveredConversations: [selectedCodex]),
            TestDeletionAdapter(provider: .antigravity, discoveredConversations: [selectedAntigravity]),
        ])

        store.refresh()
        try await waitUntil { !store.isLoading }
        let deletionPlan = store.deletionPlan(for: selectedProject.path)
        #expect(deletionPlan.deletableConversations.map(\.id).sorted() == [selectedClaude.id, selectedCodex.id].sorted())
        #expect(deletionPlan.unsupportedCount == 1)

        store.deleteSessions(in: selectedProject.path)
        try await waitUntil { store.deletingProjectPath == nil }
        #expect(!FileManager.default.fileExists(atPath: selectedClaude.sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: selectedCodex.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: selectedAntigravity.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: otherClaude.sourceFile.path))
        #expect(store.conversations.map(\.id).sorted() == [selectedAntigravity.id, otherClaude.id].sorted())
        #expect(store.errorMessage == nil)
    }

    @MainActor private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }
}
