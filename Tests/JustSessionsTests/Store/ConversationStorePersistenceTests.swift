import Foundation
import Testing

@testable import JustSessions

@MainActor
struct ConversationStorePersistenceTests {
    @Test func customTitleSurvivesARelaunch() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let conversation = Conversation.fixture(title: "Suggested")

        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        store.rename(conversation, to: "  My title  ")
        let relaunchedStore = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        #expect(store.title(for: conversation) == "My title")
        #expect(relaunchedStore.title(for: conversation) == "My title")
    }

    @Test(arguments: ["", "   ", "\n\t", "Suggested", "  Suggested  "])
    func renamingToNothingOrTheSuggestedTitleClearsTheCustomTitle(_ clearingTitle: String) throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let conversation = Conversation.fixture(title: "Suggested")
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        store.rename(conversation, to: "Custom")
        store.rename(conversation, to: clearingTitle)

        #expect(store.title(for: conversation) == "Suggested")
        #expect(ConversationTitleAliases.load(from: isolatedUserDefaults.userDefaults).customTitlesByConversationID.isEmpty)
    }

    @Test func pinsAndProjectNamesSurviveARelaunch() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let conversation = Conversation.fixture(projectPath: "/work/app")

        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        store.setPinned(true, projectPath: "/work/app")
        store.setPinned(true, conversation: conversation)
        store.renameProject("/work/app", to: "The App")
        let relaunchedStore = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        #expect(relaunchedStore.pinnedItems.isPinned(projectPath: "/work/app"))
        #expect(relaunchedStore.pinnedItems.isPinned(conversationID: conversation.id))
        #expect(relaunchedStore.projectDisplayName(forProjectPath: "/work/app") == "The App")
        #expect(relaunchedStore.projectDisplayName(forProjectPath: "/work/other") == "other")
    }

    @Test func messageBookmarksSurviveARelaunch() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let conversation = Conversation.fixture(host: .ssh("devbox"))
        let entry = TranscriptEntry(
            id: TranscriptPageIdentity.entryID(record: 7, part: 0),
            content: .userMessage("Why does the  build\nfail?"), timestamp: nil, startsTurn: true)

        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        store.toggleMessageBookmark(on: entry, in: conversation)
        let relaunchedStore = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        #expect(
            relaunchedStore.messageBookmarks.bookmarks(forConversationID: conversation.id)
                == [MessageBookmark(letter: "a", entryID: entry.id, kind: .user, snippet: "Why does the build fail?")])
        #expect(relaunchedStore.messageBookmarks == store.messageBookmarks)
    }

    @Test func archivingAndRemovingAnSSHHostKeepBookmarks() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let cacheRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheRoot) }
        let conversation = Conversation.fixture(host: .ssh("devbox"))
        RemoteHostList(hosts: ["devbox"]).save(to: isolatedUserDefaults.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        store.replaceConversations(on: .ssh("devbox"), with: [conversation])
        store.toggleMessageBookmark(
            on: TranscriptEntry(
                id: TranscriptPageIdentity.entryID(record: 3, part: 0),
                content: .assistantMessage("Done."), timestamp: nil, startsTurn: true),
            in: conversation)
        let saved = MessageBookmarks.load(from: isolatedUserDefaults.userDefaults)

        store.setArchived(true, conversations: [conversation])
        store.removeRemoteHost("devbox", mirror: RemoteSessionMirror(cacheRoot: cacheRoot))

        #expect(!saved.bookmarks(forConversationID: conversation.id).isEmpty)
        #expect(MessageBookmarks.load(from: isolatedUserDefaults.userDefaults) == saved)
        #expect(store.messageBookmarks == saved)
    }

    @Test func removingAnSSHHostForgetsItsSessionsSettingAndMirror() async throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let cacheRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheRoot) }
        let mirror = RemoteSessionMirror(cacheRoot: cacheRoot)
        let removedHostMirror = mirror.mirrorDirectory(host: "devbox", provider: .claude)
        let keptHostMirror = mirror.mirrorDirectory(host: "buildbox", provider: .claude)
        for folder in [removedHostMirror, keptHostMirror] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        RemoteHostList(hosts: ["devbox", "buildbox"]).save(to: isolatedUserDefaults.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        store.replaceConversations(on: .ssh("devbox"), with: [.fixture(host: .ssh("devbox"))])
        store.replaceConversations(on: .ssh("buildbox"), with: [.fixture(host: .ssh("buildbox"))])

        store.removeRemoteHost("devbox", mirror: mirror)

        #expect(store.remoteHostList.hosts == ["buildbox"])
        #expect(RemoteHostList.load(from: isolatedUserDefaults.userDefaults).hosts == ["buildbox"])
        #expect(store.conversations.map(\.host) == [.ssh("buildbox")])
        try await expectEventually { !FileManager.default.fileExists(atPath: removedHostMirror.path) }
        #expect(FileManager.default.fileExists(atPath: keptHostMirror.path))
    }
}
