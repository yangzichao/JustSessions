import AppKit

/// One reading window per session, keyed by its host-qualified ID. Closing it releases its retained workspace.
@MainActor
final class SessionReadingWindowManager {
    static let shared = SessionReadingWindowManager()
    private var controllersByConversationID: [String: SessionReadingWindowController] = [:]

    /// With `showingFind`, the reader opens Find, or puts the keyboard back in it in a window already open. With
    /// `navigation`, a new window opens there and one already open goes there (RDR-45, RDR-50).
    @discardableResult
    func open(
        _ conversation: Conversation, store: ConversationStore, initialPosition: TranscriptReadingPosition? = nil,
        showingFind: Bool = false, navigation: SessionReadingNavigation? = nil
    ) -> NSWindow {
        let bookmarks = { store.messageBookmarks.bookmarks(forConversationID: conversation.id) }
        if let controller = controllersByConversationID[conversation.id] {
            if showingFind { controller.requests.requestFind() }
            switch navigation {
            case .adjacentBookmark(let forward)?:
                // As ⌘' in the window: from the message being read, or, while no pages show, from where it was left
                // (TranscriptView.waitingNavigationTarget). A window not yet drawn shows none.
                if let target = TranscriptBookmarkTargetRegistry.shared.target(in: controller.readingWindow) {
                    target.goToAdjacentBookmark(forward)
                } else {
                    controller.requests.requestAdjacentBookmark(
                        forward: forward, in: bookmarks(), from: controller.readingPositionStore.position(for: conversation.id))
                }
            case let navigation?: controller.requests.request(navigation)
            case nil: break
            }
            controller.readingWindow.makeKeyAndOrderFront(nil)
            return controller.readingWindow
        }
        let navigation = navigation?.forNewWindow(bookmarks: bookmarks())
        let position = navigation?.entryID.map { TranscriptReadingPosition.entry(index: $0, offset: -6) } ?? initialPosition
        let controller = SessionReadingWindowController(conversation: conversation, store: store, initialPosition: position) {
            [weak self] in
            self?.controllersByConversationID.removeValue(forKey: conversation.id)
        }
        controllersByConversationID[conversation.id] = controller
        if showingFind { controller.requests.requestFind() }
        // Taken in a new window too, as its first page shows: it sets the seek target ⌘' goes on from.
        if let navigation { controller.requests.request(navigation) }
        let window = controller.readingWindow
        window.makeKeyAndOrderFront(nil)
        return window
    }
}
