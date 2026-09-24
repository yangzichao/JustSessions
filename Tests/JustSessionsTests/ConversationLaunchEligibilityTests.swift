import Foundation
import Testing
@testable import JustSessions

struct ConversationLaunchEligibilityTests {
    @Test @MainActor func multiSelectionLaunchSkipsMissingFoldersAndUnsupportedBranches() throws {
        let existingProject = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: existingProject, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: existingProject) }
        let missingProject = existingProject.appendingPathComponent("missing")

        let claudeInExistingProject = conversation(.claude, project: existingProject)
        let antigravityInExistingProject = conversation(.antigravity, project: existingProject)
        let claudeInMissingProject = conversation(.claude, project: missingProject)
        let store = ConversationStore(adapters: [])

        #expect(store.canLaunch(claudeInExistingProject, action: .resume))
        #expect(store.canLaunch(claudeInExistingProject, action: .branch))
        #expect(store.canLaunch(antigravityInExistingProject, action: .resume))
        #expect(!store.canLaunch(antigravityInExistingProject, action: .branch))
        #expect(!store.canLaunch(claudeInMissingProject, action: .resume))
    }

    private func conversation(_ provider: ConversationProvider, project: URL) -> Conversation {
        let sessionID = UUID().uuidString
        return Conversation(
            provider: provider,
            sessionID: sessionID,
            projectPath: project.path,
            suggestedTitle: sessionID,
            updatedAt: .now,
            sourceFile: URL(fileURLWithPath: "/tmp/\(sessionID).jsonl")
        )
    }
}
