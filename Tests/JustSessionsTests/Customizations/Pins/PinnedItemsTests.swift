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

    @Test func pinnedProjectsKeepTheirOrderWhateverTheirActivity() {
        let firstPinned = conversation(project: URL(fileURLWithPath: "/tmp/first-pinned").path, time: 10)
        let secondPinned = conversation(project: URL(fileURLWithPath: "/tmp/second-pinned").path, time: 30)
        let unpinned = conversation(project: URL(fileURLWithPath: "/tmp/unpinned").path, time: 20)
        var pinnedItems = PinnedItems()
        pinnedItems.setPinned(true, projectPath: firstPinned.projectDirectoryKey)
        pinnedItems.setPinned(true, projectPath: secondPinned.projectDirectoryKey)

        let groups = ProjectConversationGroup.grouped([firstPinned, secondPinned, unpinned], pinnedItems: pinnedItems)
        #expect(groups.map(\.projectPath) == [
            firstPinned.projectDirectoryKey, secondPinned.projectDirectoryKey, unpinned.projectDirectoryKey,
        ])

        pinnedItems.movePinnedProject(secondPinned.projectDirectoryKey, to: .before(firstPinned.projectDirectoryKey))
        let movedGroups = ProjectConversationGroup.grouped([firstPinned, secondPinned, unpinned], pinnedItems: pinnedItems)
        #expect(movedGroups.map(\.projectPath) == [
            secondPinned.projectDirectoryKey, firstPinned.projectDirectoryKey, unpinned.projectDirectoryKey,
        ])
    }

    @Test func pinnedSessionsKeepTheirOrderWhateverTheirActivity() {
        let project = URL(fileURLWithPath: "/tmp/example-project").path
        let older = conversation(project: project, time: 10)
        let newer = conversation(project: project, time: 20)
        let unpinnedNewest = conversation(project: project, time: 30)
        let pinnedItems = PinnedItems(pinnedConversationIDs: [older.id, newer.id])

        #expect(pinnedItems.pinnedConversationsFirst([unpinnedNewest, newer, older]).map(\.id) == [
            older.id, newer.id, unpinnedNewest.id,
        ])
    }

    @Test func pinsSurviveASaveAndLoadInTheirOrder() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let userDefaults = isolatedUserDefaults.userDefaults
        let pinnedItems = PinnedItems(
            pinnedProjectPaths: ["/tmp/zeta", "/tmp/alpha"],
            pinnedConversationIDs: ["Codex:xyz", "Codex:abc"]
        )

        pinnedItems.save(to: userDefaults)

        let loaded = PinnedItems.load(from: userDefaults)
        #expect(loaded == pinnedItems)
        #expect(loaded.pinnedProjectPaths == ["/tmp/zeta", "/tmp/alpha"])
        #expect(loaded.pinnedConversationIDs == ["Codex:xyz", "Codex:abc"])
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
