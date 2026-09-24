import Foundation
import Testing
@testable import ClaudexMacOS

struct ProjectConversationGroupTests {
    @Test func sameFolderCombinesProvidersAndSortsByActivity() {
        let project = URL(fileURLWithPath: "/tmp/example-project").path
        let otherProject = URL(fileURLWithPath: "/tmp/other-project").path
        let olderClaude = conversation(.claude, id: UUID().uuidString, project: project, time: 10)
        let newerCodex = conversation(.codex, id: UUID().uuidString, project: project + "/./", time: 30)
        let otherCodex = conversation(.codex, id: UUID().uuidString, project: otherProject, time: 20)

        let groups = ProjectConversationGroup.grouped([olderClaude, otherCodex, newerCodex])

        #expect(groups.count == 2)
        #expect(groups[0].projectPath == olderClaude.projectDirectoryKey)
        #expect(groups[0].conversations.map(\.provider) == [.codex, .claude])
        #expect(groups[1].conversations.map(\.id) == [otherCodex.id])
    }

    private func conversation(
        _ provider: ConversationProvider,
        id: String,
        project: String,
        time: TimeInterval
    ) -> Conversation {
        Conversation(
            provider: provider,
            sessionID: id,
            projectPath: project,
            suggestedTitle: "Example",
            updatedAt: Date(timeIntervalSince1970: time),
            sourceFile: URL(fileURLWithPath: "/tmp/\(id).jsonl")
        )
    }
}
