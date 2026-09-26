import Foundation
import Testing
@testable import JustSessions

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

    @Test func newSessionShowsUnderItsProjectBeforeTheCLISavesAnything() {
        let savedProject = URL(fileURLWithPath: "/tmp/example-project").path
        let saved = conversation(.claude, id: UUID().uuidString, project: savedProject, time: 10)
        let brandNewProjectSession = pendingNewSession(project: "/tmp/brand-new-project", time: 20)
        let savedProjectSession = pendingNewSession(project: savedProject, time: 5)

        let groups = ProjectConversationGroup.grouped([saved], pendingNewSessions: [savedProjectSession, brandNewProjectSession])

        #expect(groups.map(\.projectPath) == [brandNewProjectSession.projectDirectoryKey, saved.projectDirectoryKey])
        #expect(groups[0].conversations.isEmpty)
        #expect(groups[0].pendingNewSessions == [brandNewProjectSession])
        #expect(groups[0].sessionCount == 1)
        #expect(groups[1].pendingNewSessions == [savedProjectSession])
        #expect(groups[1].sessionCount == 2)
        #expect(groups[1].latestActivity == saved.updatedAt)
    }

    private func pendingNewSession(project: String, time: TimeInterval) -> PendingNewSession {
        PendingNewSession(
            terminalID: UUID(),
            provider: .codex,
            projectDirectoryKey: URL(fileURLWithPath: project).standardizedFileURL.resolvingSymlinksInPath().path,
            title: "New Codex session",
            startedAt: Date(timeIntervalSince1970: time)
        )
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
