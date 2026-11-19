import Foundation
import Testing

@testable import JustSessions

@MainActor
struct SharedCustomizationsTests {
    @Test func aRenameShowsInEveryWindowAndKeepsTheOtherWindowsRenames() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let registry = WorkspaceWindowRegistry()
        let first = Conversation.fixture(title: "First suggested")
        let second = Conversation.fixture(title: "Second suggested")
        let firstWindow = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults, windowRegistry: registry)
        let secondWindow = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults, windowRegistry: registry)

        firstWindow.rename(first, to: "Renamed in the first window")
        #expect(secondWindow.title(for: first) == "Renamed in the first window")

        secondWindow.rename(second, to: "Renamed in the second window")
        let relaunched = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        #expect(firstWindow.title(for: second) == "Renamed in the second window")
        #expect(relaunched.title(for: first) == "Renamed in the first window")
        #expect(relaunched.title(for: second) == "Renamed in the second window")
    }

    @Test func aChangeStartsFromWhatIsSavedNotFromTheWindowsOwnCopy() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let renamed = Conversation.fixture(title: "Suggested")
        let pinned = Conversation.fixture(title: "Pinned")
        let archived = Conversation.fixture(title: "Archived")
        let unaware = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let other = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        other.rename(renamed, to: "Kept")
        other.renameProject("/work/app", to: "The App")
        other.setPinned(true, conversation: pinned)
        other.setArchived(true, conversations: [archived])
        unaware.rename(Conversation.fixture(title: "Another"), to: "Also kept")
        unaware.renameProject("/work/api", to: "The API")
        unaware.setPinned(true, projectPath: "/work/app")
        unaware.setArchived(true, conversations: [pinned])
        let relaunched = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        #expect(relaunched.title(for: renamed) == "Kept")
        #expect(relaunched.projectDisplayName(forProjectPath: "/work/app") == "The App")
        #expect(relaunched.projectDisplayName(forProjectPath: "/work/api") == "The API")
        #expect(relaunched.pinnedItems.isPinned(conversationID: pinned.id))
        #expect(relaunched.pinnedItems.isPinned(projectPath: "/work/app"))
        #expect(relaunched.archivedSessions.isArchived(conversationID: archived.id))
        #expect(relaunched.archivedSessions.isArchived(conversationID: pinned.id))
    }

    @Test func pinsArchivingAndProjectNamesShowInEveryWindow() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let registry = WorkspaceWindowRegistry()
        let conversation = Conversation.fixture(title: "Suggested")
        let firstWindow = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults, windowRegistry: registry)
        let secondWindow = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults, windowRegistry: registry)

        firstWindow.renameProject("/work/app", to: "The App")
        firstWindow.setPinned(true, conversation: conversation)
        firstWindow.setArchived(true, conversations: [conversation])

        #expect(secondWindow.projectDisplayName(forProjectPath: "/work/app") == "The App")
        #expect(secondWindow.pinnedItems.isPinned(conversationID: conversation.id))
        #expect(secondWindow.archivedSessions.isArchived(conversationID: conversation.id))
    }

    @Test func aBookmarkShowsInEveryWindow() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let registry = WorkspaceWindowRegistry()
        let conversation = Conversation.fixture(title: "Suggested")
        let firstWindow = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults, windowRegistry: registry)
        let secondWindow = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults, windowRegistry: registry)

        firstWindow.toggleMessageBookmark(on: message(record: 4), in: conversation)
        #expect(secondWindow.messageBookmarks.bookmarks(forConversationID: conversation.id).map(\.letter) == ["a"])

        secondWindow.removeAllMessageBookmarks(in: conversation)
        #expect(firstWindow.messageBookmarks.bookmarks(forConversationID: conversation.id).isEmpty)
    }

    @Test func twoWindowsNeverHandOutTheSameLetter() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let conversation = Conversation.fixture(title: "Suggested")
        let unaware = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let other = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        let first = other.toggleMessageBookmark(on: message(record: 1), in: conversation)
        let second = unaware.toggleMessageBookmark(on: message(record: 2), in: conversation)
        let relaunched = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        guard case .added(let a) = first, case .added(let b) = second else {
            Issue.record("Both toggles should add a bookmark")
            return
        }
        #expect([a.letter, b.letter] == ["a", "b"])
        #expect(relaunched.messageBookmarks.bookmarks(forConversationID: conversation.id).map(\.letter) == ["a", "b"])
    }

    @Test func aWindowThatMissedABookmarkKeepsItRatherThanRemovingIt() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let conversation = Conversation.fixture(title: "Suggested")
        let unaware = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let other = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let added = other.toggleMessageBookmark(on: message(record: 1), in: conversation)

        let toggle = unaware.toggleMessageBookmark(on: message(record: 1), in: conversation)
        let relaunched = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        #expect(toggle == added)
        #expect(relaunched.messageBookmarks.bookmarks(forConversationID: conversation.id).map(\.letter) == ["a"])
        #expect(unaware.messageBookmarks.bookmarks(forConversationID: conversation.id).map(\.letter) == ["a"])
    }

    @Test func aWindowThatMissedARemovalDoesNotBookmarkTheMessageAgain() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let conversation = Conversation.fixture(title: "Suggested")
        let other = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        other.toggleMessageBookmark(on: message(record: 1), in: conversation)
        let unaware = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        other.toggleMessageBookmark(on: message(record: 1), in: conversation)

        let toggle = unaware.toggleMessageBookmark(on: message(record: 1), in: conversation)
        let relaunched = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        guard case .removed(let removed) = toggle else {
            Issue.record("The toggle should remove the bookmark the window shows")
            return
        }
        #expect(removed.letter == "a")
        #expect(relaunched.messageBookmarks.bookmarks(forConversationID: conversation.id).isEmpty)
        #expect(unaware.messageBookmarks.bookmarks(forConversationID: conversation.id).isEmpty)
    }

    private func message(record: Int) -> TranscriptEntry {
        TranscriptEntry(
            id: TranscriptPageIdentity.entryID(record: record, part: 0), content: .userMessage("Message \(record)"),
            timestamp: nil, startsTurn: true)
    }
}
