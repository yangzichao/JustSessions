import AppKit
import Testing

@testable import JustSessions

@MainActor
struct SessionReadingWindowTests {
    @Test func openingAndReusingAReadingWindowDoesNotLaunchATerminal() throws {
        _ = NSApplication.shared
        WindowAnimations.disable()
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier())
        let conversation = TranscriptScrollViewFixture.conversation("read-without-resume")
        let manager = SessionReadingWindowManager()

        let firstWindow = manager.open(conversation, store: store)
        let reopenedWindow = manager.open(conversation, store: store)
        #expect(firstWindow === reopenedWindow)
        #expect(firstWindow.styleMask.contains(.resizable))
        #expect(store.terminalSessions.isEmpty)
        #expect(store.selectedTerminalID == nil)
        firstWindow.close()

        let freshWindow = manager.open(conversation, store: store)
        defer { freshWindow.close() }
        #expect(freshWindow !== firstWindow)
        #expect(store.terminalSessions.isEmpty)
    }

    /// ⌘F in a tab linked to the session opens its reading window with Find, and in a window already open asks Find
    /// again, which puts the keyboard back in its field. Opening the window otherwise asks nothing.
    @Test func openingForFindAsksTheReaderToShowFind() throws {
        _ = NSApplication.shared
        WindowAnimations.disable()
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier())
        let conversation = TranscriptScrollViewFixture.conversation("find-from-tab")
        let manager = SessionReadingWindowManager()
        let tab = TerminalSession(
            engine: .swiftTerm, conversation: conversation, provider: .codex, projectPath: "/tmp/reading-position",
            action: .resume, displayTitle: "Find from tab",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: [])
        )
        store.openTerminal(tab)
        defer { store.closeAllTerminals() }

        let window = manager.open(conversation, store: store, showingFind: true)
        defer { window.close() }
        let controller = try #require(window.windowController as? SessionReadingWindowController)
        #expect(controller.requests.findRevision == 1)

        #expect(manager.open(conversation, store: store) === window)
        #expect(controller.requests.findRevision == 1)
        #expect(manager.open(conversation, store: store, showingFind: true) === window)
        #expect(controller.requests.findRevision == 2)
        #expect(store.selectedTerminalID == tab.id)
    }

    @Test func aNavigationIsTakenOnce() {
        let requests = SessionReadingRequests()
        requests.request(.entry(42))

        #expect(requests.navigationRevision == 1)
        #expect(requests.takeNavigation() == .entry(42))
        #expect(requests.takeNavigation() == nil)
    }

    @Test func aNewerNavigationReplacesOneNotTaken() {
        let requests = SessionReadingRequests()
        requests.request(.entry(42))
        requests.request(.adjacentBookmark(forward: false))

        #expect(requests.navigationRevision == 2)
        #expect(requests.takeNavigation() == .adjacentBookmark(forward: false))
    }

    /// ⌘' pressed again before the reader took the first press goes on from the bookmark that press asked for.
    @Test func pressesBeforeTheReaderTakesARequestAddUp() {
        let bookmarks = ["a", "b", "c"].enumerated().map { index, letter in
            MessageBookmark(
                letter: letter, entryID: TranscriptPageIdentity.entryID(record: 10 * (index + 1), part: 0),
                kind: .assistant, snippet: "Message \(letter)")
        }
        let requests = SessionReadingRequests()

        requests.request(.bookmark(bookmarks[0]))
        requests.requestAdjacentBookmark(forward: true, in: bookmarks, from: nil)
        #expect(requests.pendingNavigation == .bookmark(bookmarks[1]))

        requests.request(.bookmark(bookmarks[2]))
        requests.requestAdjacentBookmark(forward: true, in: bookmarks, from: nil)
        #expect(requests.pendingNavigation == .bookmark(bookmarks[0]))

        requests.requestAdjacentBookmark(forward: false, in: bookmarks, from: nil)
        #expect(requests.pendingNavigation == .bookmark(bookmarks[2]))

        // With nothing waiting, from where the window was left; the bottom is the conversation's end.
        _ = requests.takeNavigation()
        requests.requestAdjacentBookmark(forward: true, in: bookmarks, from: .entry(index: bookmarks[0].entryID + 1, offset: -6))
        #expect(requests.pendingNavigation == .bookmark(bookmarks[1]))
        _ = requests.takeNavigation()
        requests.requestAdjacentBookmark(forward: false, in: bookmarks, from: .bottom)
        #expect(requests.pendingNavigation == .bookmark(bookmarks[2]))

        // With no bookmarks, the reader says so.
        _ = requests.takeNavigation()
        requests.requestAdjacentBookmark(forward: true, in: [], from: nil)
        #expect(requests.pendingNavigation == .adjacentBookmark(forward: true))
    }

    @Test func aMapClickOpensANewWindowAtTheEntry() throws {
        _ = NSApplication.shared
        WindowAnimations.disable()
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier())
        let conversation = TranscriptScrollViewFixture.conversation("map-click")
        let manager = SessionReadingWindowManager()
        let entryID = TranscriptPageIdentity.entryID(record: 120, part: 0)
        // The map's tab, selected, as the click leaves it.
        let tab = TerminalSession(
            engine: .swiftTerm, conversation: conversation, provider: .codex, projectPath: "/tmp/map-click", action: .resume,
            displayTitle: "Map click",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: [])
        )
        store.openTerminal(tab)
        defer { store.closeAllTerminals() }

        let window = manager.open(conversation, store: store, navigation: .entry(entryID))
        defer { window.close() }
        let controller = try #require(window.windowController as? SessionReadingWindowController)

        #expect(controller.readingPositionStore.position(for: conversation.id) == .entry(index: entryID, offset: -6))
        #expect(controller.requests.pendingNavigation == .entry(entryID))
        #expect(store.selectedTerminalID == tab.id)
    }

    /// Deleting the session forgot its bookmarks; a reading window left open on it offers none, so none are saved again.
    @Test func aReadingWindowOnASessionNoLongerListedKeepsNoBookmarks() async throws {
        _ = NSApplication.shared
        WindowAnimations.disable()
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let files = try TranscriptPagingFixture(count: 10)
        defer { files.remove() }
        let store = ConversationStore(
            adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier(),
            startsBackgroundPolling: false)
        store.replaceConversations(on: .thisMac, with: [files.conversation])
        let manager = SessionReadingWindowManager()
        let window = manager.open(files.conversation, store: store)
        defer { window.close() }
        try await expectEventually { TranscriptBookmarkTargetRegistry.shared.target(keyWindow: window) != nil }

        store.replaceConversations(on: .thisMac, with: [])

        try await expectEventually { TranscriptBookmarkTargetRegistry.shared.target(keyWindow: window) == nil }
        #expect(TranscriptBookmarkTargetRegistry.shared.target(keyWindow: window) == nil)
    }

    @Test func sessionsOnDifferentHostsGetSeparateReadingWindows() throws {
        _ = NSApplication.shared
        WindowAnimations.disable()
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier())
        let first = TranscriptScrollViewFixture.conversation("host-qualified")
        let second = first.onHost(.ssh("reading-fixture.example"))
        let manager = SessionReadingWindowManager()
        let firstWindow = manager.open(first, store: store)
        let secondWindow = manager.open(second, store: store)
        defer {
            firstWindow.close()
            secondWindow.close()
        }
        #expect(firstWindow !== secondWindow)
        #expect(manager.open(first, store: store) === firstWindow)
        #expect(store.terminalSessions.isEmpty)
    }
}
