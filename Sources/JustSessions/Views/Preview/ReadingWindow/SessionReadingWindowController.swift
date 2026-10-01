import AppKit
import SwiftUI

@MainActor
final class SessionReadingWindowController: NSWindowController, NSWindowDelegate {
    let readingWindow: NSWindow
    private let onClose: () -> Void

    init(conversation: Conversation, store: ConversationStore, initialPosition: TranscriptReadingPosition?, onClose: @escaping () -> Void) {
        self.onClose = onClose
        let positionStore = TranscriptReadingPositionStore()
        if let initialPosition { positionStore.record(initialPosition, for: conversation.id) }
        let content = SessionReadingView(store: store, conversation: conversation, readingPositionStore: positionStore)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = store.title(for: conversation)
        window.contentViewController = NSHostingController(rootView: content.appTheme(from: .shared))
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 350)
        readingWindow = window
        super.init(window: window)
        window.delegate = self
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
