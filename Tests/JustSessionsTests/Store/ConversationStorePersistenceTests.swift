import Foundation
import Testing
@testable import JustSessions

/// What the store keeps in settings comes back in the next store, as it would after relaunching the app.
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
