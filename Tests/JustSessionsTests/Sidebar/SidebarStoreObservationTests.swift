import Testing

@testable import JustSessions

@MainActor
struct SidebarStoreObservationTests {
    @Test func identicalRefreshAndTabSelectionDoNotPublishButChangedTitlesDo() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(
            adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier(), startsBackgroundPolling: false)
        let first = Conversation.fixture()
        let other = Conversation.fixture()
        store.replaceConversations(on: .thisMac, with: [first, other])
        let publications = StoreChangeCounter(store) { _ = $0.conversations }
        let selections = StoreChangeCounter(store) { _ = $0.selectedTerminalID }
        defer {
            publications.cancel()
            selections.cancel()
        }
        store.selectTerminal(nil)
        #expect(selections.mainActorTurnsWithChanges == 0)
        store.replaceConversations(on: .thisMac, with: [first, other])
        #expect(publications.mainActorTurnsWithChanges == 0)
        store.replaceConversations(on: .thisMac, with: [first.withSuggestedTitle("Changed"), other])
        #expect(publications.mainActorTurnsWithChanges == 1)
    }

    @Test func unchangedTmuxSessionsAndLoginStateDoNotPublish() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        RemoteHostList(hosts: ["devbox"]).save(to: settings.userDefaults)
        let store = ConversationStore(
            adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier(), startsBackgroundPolling: false)
        let connections = SSHLoginConnections()
        store.setTmuxSessionNames(["justsessions-claude-a"], on: .ssh("devbox"))
        store.noteLoginState(on: "devbox", refreshProblem: .hostKeyNotTrusted, connections: connections)
        #expect(store.sshHostsNeedingLogIn == ["devbox"])
        let publications = StoreChangeCounter(store) {
            _ = $0.tmuxSessionNamesByHost
            _ = $0.sshHostsNeedingLogIn
            _ = $0.sshHostsLoggedIn
        }
        defer { publications.cancel() }

        store.setTmuxSessionNames(["justsessions-claude-a"], on: .ssh("devbox"))
        store.noteLoginState(on: "devbox", refreshProblem: .hostKeyNotTrusted, connections: connections)
        #expect(publications.mainActorTurnsWithChanges == 0)

        store.noteLoginState(on: "devbox", refreshProblem: nil, connections: connections)
        #expect(publications.mainActorTurnsWithChanges == 1)
        #expect(store.sshHostsNeedingLogIn.isEmpty)
    }

    @Test func aBookmarkChangePublishesOnlyBookmarks() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(
            adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier(), startsBackgroundPolling: false)
        let conversation = Conversation.fixture()
        store.replaceConversations(on: .thisMac, with: [conversation])
        let entry = TranscriptEntry(
            id: TranscriptPageIdentity.entryID(record: 1, part: 0), content: .userMessage("Hello"),
            timestamp: nil, startsTurn: true)
        let sidebar = StoreChangeCounter(store) {
            _ = $0.conversations
            _ = $0.titleAliases
            _ = $0.pinnedItems
            _ = $0.archivedSessions
        }
        let bookmarks = StoreChangeCounter(store) { _ = $0.messageBookmarks }
        defer {
            sidebar.cancel()
            bookmarks.cancel()
        }
        store.removeMessageBookmark(MessageBookmark(letter: "a", entryID: entry.id, kind: .user, snippet: "Hello"), in: conversation)
        #expect(bookmarks.mainActorTurnsWithChanges == 0)

        store.toggleMessageBookmark(on: entry, in: conversation)

        #expect(bookmarks.mainActorTurnsWithChanges == 1)
        #expect(sidebar.mainActorTurnsWithChanges == 0)
    }
}
