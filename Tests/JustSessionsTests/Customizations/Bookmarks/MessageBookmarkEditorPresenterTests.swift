import AppKit
import SwiftUI
import Testing

@testable import JustSessions

/// Edit Bookmark… and All Bookmarks show as sheets on the window they were asked for (RDR-51, RDR-52). Windows are on
/// screen and titled, which SwiftUI needs before it attaches a sheet.
@MainActor
@Suite(.serialized)
struct MessageBookmarkEditorPresenterTests {
    private func onScreenWindow(showing view: some View) -> NSWindow {
        _ = NSApplication.shared
        WindowAnimations.disable()
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 700, height: 640), styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.orderFrontRegardless()
        return window
    }

    private func close(_ window: NSWindow) {
        window.attachedSheet.map { window.endSheet($0) }
        window.close()
    }

    @Test func aRequestShowsTheEditorAndClosingItEndsTheRequest() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        let requests = MessageBookmarkEditorRequests()
        let window = onScreenWindow(showing: Color.clear.messageBookmarkEditor(requests, store: store))
        defer { close(window) }
        let conversation = Conversation.fixture(provider: .codex, sessionID: "editor")
        let bookmark = MessageBookmark(
            letter: "a", entryID: TranscriptPageIdentity.entryID(record: 1, part: 0), kind: .user,
            snippet: "Hello")

        requests.open(bookmark, in: conversation)

        try await expectEventually { window.attachedSheet != nil }
        requests.request = nil
        try await expectEventually { window.attachedSheet == nil }
    }

    @Test func aClickOnTheWindowAroundTheEditorClosesIt() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        let requests = MessageBookmarkEditorRequests()
        let window = onScreenWindow(showing: Color.clear.messageBookmarkEditor(requests, store: store))
        defer { close(window) }
        let bookmark = MessageBookmark(
            letter: "a", entryID: TranscriptPageIdentity.entryID(record: 1, part: 0), kind: .user,
            snippet: "Hello")
        requests.open(bookmark, in: Conversation.fixture(provider: .codex, sessionID: "editor-click-outside"))
        try await expectEventually { window.attachedSheet != nil }

        NSApp.sendEvent(
            try #require(
                NSEvent.mouseEvent(
                    with: .leftMouseDown, location: CGPoint(x: 20, y: 20), modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 0, clickCount: 1, pressure: 1
                )))

        #expect(requests.request == nil)
        try await expectEventually { window.attachedSheet == nil }
    }

    @Test func showAllBookmarksAsksTheFrontmostWorkspaceWindowsStore() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let registry = WorkspaceWindowRegistry()
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        let window = onScreenWindow(showing: Color.clear.modifier(AllBookmarksPresenter(store: store)))
        defer { close(window) }
        registry.add(store)
        registry.setWindowHandingOverItsFirstWindow(window, for: store)

        AllBookmarksCommand.show(registry: registry)

        #expect(store.showsAllBookmarks)
        try await expectEventually { window.attachedSheet != nil }
    }
}
