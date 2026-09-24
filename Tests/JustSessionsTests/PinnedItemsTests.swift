import Foundation
import Testing
@testable import JustSessions

struct PinnedItemsTests {
    @Test func pinnedProjectsAndSessionsSortFirst() {
        let busyProject = URL(fileURLWithPath: "/tmp/busy-project").path
        let quietProject = URL(fileURLWithPath: "/tmp/quiet-project").path
        let busyNewest = conversation(project: busyProject, time: 40)
        let quietNewest = conversation(project: quietProject, time: 20)
        let quietOldest = conversation(project: quietProject, time: 10)
        var pinnedItems = PinnedItems()
        pinnedItems.setPinned(true, projectPath: quietOldest.projectDirectoryKey)
        pinnedItems.setPinned(true, conversationID: quietOldest.id)

        let groups = ProjectConversationGroup.grouped([busyNewest, quietNewest, quietOldest], pinnedItems: pinnedItems)

        #expect(groups.map(\.projectPath) == [quietOldest.projectDirectoryKey, busyNewest.projectDirectoryKey])
        #expect(groups.map(\.isPinned) == [true, false])
        #expect(groups[0].conversations.map(\.id) == [quietOldest.id, quietNewest.id])
        // Activity still comes from the newest session, not the pinned one listed first.
        #expect(groups[0].latestActivity == quietNewest.updatedAt)
    }

    @Test func unpinningRestoresActivityOrder() {
        let project = URL(fileURLWithPath: "/tmp/example-project").path
        let newer = conversation(project: project, time: 20)
        let older = conversation(project: project, time: 10)
        var pinnedItems = PinnedItems(pinnedConversationIDs: [older.id])
        #expect(pinnedItems.pinnedConversationsFirst([newer, older]).map(\.id) == [older.id, newer.id])

        pinnedItems.setPinned(false, conversationID: older.id)
        #expect(pinnedItems.pinnedConversationsFirst([newer, older]).map(\.id) == [newer.id, older.id])
    }

    @Test func pinsSurviveASaveAndLoad() throws {
        let suiteName = "PinnedItemsTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let pinnedItems = PinnedItems(pinnedProjectPaths: ["/tmp/project"], pinnedConversationIDs: ["Codex:abc"])

        pinnedItems.save(to: userDefaults)

        #expect(PinnedItems.load(from: userDefaults) == pinnedItems)
    }

    private func conversation(project: String, time: TimeInterval) -> Conversation {
        let sessionID = UUID().uuidString
        return Conversation(
            provider: .claude,
            sessionID: sessionID,
            projectPath: project,
            suggestedTitle: "Example",
            updatedAt: Date(timeIntervalSince1970: time),
            sourceFile: URL(fileURLWithPath: "/tmp/\(sessionID).jsonl")
        )
    }
}
