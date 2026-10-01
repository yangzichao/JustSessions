import AppKit

/// One reading window per session, keyed by its host-qualified ID. Closing it releases its retained workspace.
@MainActor
final class SessionReadingWindowManager {
    static let shared = SessionReadingWindowManager()
    private var controllersByConversationID: [String: SessionReadingWindowController] = [:]

    @discardableResult
    func open(_ conversation: Conversation, store: ConversationStore, initialPosition: TranscriptReadingPosition? = nil) -> NSWindow {
        if let window = controllersByConversationID[conversation.id]?.window {
            window.makeKeyAndOrderFront(nil)
            return window
        }
        let controller = SessionReadingWindowController(conversation: conversation, store: store, initialPosition: initialPosition) { [weak self] in
            self?.controllersByConversationID.removeValue(forKey: conversation.id)
        }
        controllersByConversationID[conversation.id] = controller
        let window = controller.readingWindow
        window.makeKeyAndOrderFront(nil)
        return window
    }
}
