import Foundation
import Testing
@testable import JustSessions

struct ProjectSessionRowTests {
    @Test func pinnedSessionsStayAboveNewSessionsAndTheNewestSession() {
        let project = URL(fileURLWithPath: "/tmp/example-project").path
        let pinnedOlder = conversation(id: "pinned-older", project: project, time: 10)
        let unpinnedNewest = conversation(id: "unpinned-newest", project: project, time: 50)
        let unpinnedOlder = conversation(id: "unpinned-older", project: project, time: 20)
        let newSession = PendingNewSession(
            terminalID: UUID(), provider: .claude, projectDirectoryKey: pinnedOlder.projectDirectoryKey,
            title: "New Claude Code session", startedAt: Date(timeIntervalSince1970: 60)
        )
        let pinnedItems = PinnedItems(pinnedConversationIDs: [pinnedOlder.id])
        let group = ProjectConversationGroup.grouped(
            [unpinnedOlder, pinnedOlder, unpinnedNewest], pendingNewSessions: [newSession], pinnedItems: pinnedItems
        )[0]

        let rows = ProjectSessionRow.ordered(
            conversations: group.conversations, pendingNewSessions: group.pendingNewSessions, pinnedItems: pinnedItems
        )

        #expect(rows.map(\.id) == [
            "conversation:\(pinnedOlder.id)",
            "pending:\(newSession.id.uuidString)",
            "conversation:\(unpinnedNewest.id)",
            "conversation:\(unpinnedOlder.id)",
        ])
    }

    @Test func withoutPinsNewSessionsComeFirst() {
        let project = URL(fileURLWithPath: "/tmp/example-project").path
        let saved = conversation(id: "saved", project: project, time: 50)
        let newSession = PendingNewSession(
            terminalID: UUID(), provider: .codex, projectDirectoryKey: saved.projectDirectoryKey,
            title: "New Codex session", startedAt: Date(timeIntervalSince1970: 60)
        )

        let rows = ProjectSessionRow.ordered(conversations: [saved], pendingNewSessions: [newSession], pinnedItems: PinnedItems())

        #expect(rows.map(\.id) == ["pending:\(newSession.id.uuidString)", "conversation:\(saved.id)"])
    }

    private func conversation(id: String, project: String, time: TimeInterval) -> Conversation {
        Conversation(
            provider: .claude,
            sessionID: id,
            projectPath: project,
            suggestedTitle: "Example",
            updatedAt: Date(timeIntervalSince1970: time),
            sourceFile: URL(fileURLWithPath: "/tmp/\(id).jsonl")
        )
    }
}
