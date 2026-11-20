import AppKit

@MainActor
final class SessionReadingWindowManager {
    static let shared = SessionReadingWindowManager()
    private var controllersByConversationID: [String: SessionReadingWindowController] = [:]

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
        let position = navigation?.entryID.map { TranscriptReadingPosition.startOfEntry($0) } ?? initialPosition
        let controller = SessionReadingWindowController(conversation: conversation, store: store, initialPosition: position) {
            [weak self] in
            self?.controllersByConversationID.removeValue(forKey: conversation.id)
        }
        controllersByConversationID[conversation.id] = controller
        if showingFind { controller.requests.requestFind() }
        if let navigation { controller.requests.request(navigation) }
        let window = controller.readingWindow
        window.makeKeyAndOrderFront(nil)
        return window
    }
}
