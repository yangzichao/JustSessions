import AppKit
import SwiftUI

@MainActor
final class SessionReadingWindowController: NSWindowController, NSWindowDelegate {
    let readingWindow: NSWindow
    let requests = SessionReadingRequests()
    let readingPositionStore = TranscriptReadingPositionStore()
    private let onClose: () -> Void
    private let userDefaults: UserDefaults

    init(
        conversation: Conversation, store: ConversationStore, initialPosition: TranscriptReadingPosition?,
        userDefaults: UserDefaults = .standard, onClose: @escaping () -> Void
    ) {
        self.onClose = onClose
        self.userDefaults = userDefaults
        if let initialPosition { readingPositionStore.record(initialPosition, for: conversation.id) }
        let content = SessionReadingView(
            store: store, conversation: conversation, readingPositionStore: readingPositionStore, requests: requests
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = store.title(for: conversation)
        window.contentViewController = NSHostingController(rootView: content.appTheme(from: .shared).appLanguage(from: .shared))
        window.isReleasedWhenClosed = false
        window.minSize = Self.minimumSize
        readingWindow = window
        super.init(window: window)
        window.delegate = self
        if let screen = NSApp.keyWindow?.screen ?? NSScreen.main {
            window.setFrame(Self.initialFrame(in: screen.visibleFrame, savedSize: Self.savedSize(in: userDefaults)), display: false)
        } else {
            window.center()
        }
    }

    static let minimumSize = NSSize(width: 400, height: 350)
    static let savedSizeKey = "readingWindowSize"
    private static let marginBesideReadableColumn: CGFloat = 120
    static let preferredWidth = TranscriptReadingWidth.readableColumnWidth + 2 * marginBesideReadableColumn
    static let screenMargin: CGFloat = 20

    static func initialFrame(in visibleFrame: CGRect, savedSize: CGSize? = nil) -> CGRect {
        let room = CGSize(width: visibleFrame.width - 2 * screenMargin, height: visibleFrame.height - 2 * screenMargin)
        let width = max(minimumSize.width, min(savedSize?.width ?? preferredWidth, room.width))
        let height = max(minimumSize.height, min(savedSize?.height ?? room.height, room.height))
        return CGRect(
            x: (visibleFrame.midX - width / 2).rounded(), y: (visibleFrame.midY - height / 2).rounded(),
            width: width, height: height)
    }

    required init?(coder: NSCoder) { nil }

    static func savedSize(in userDefaults: UserDefaults) -> CGSize? {
        guard let text = userDefaults.string(forKey: savedSizeKey) else { return nil }
        let size = NSSizeFromString(text)
        return size.width >= minimumSize.width && size.height >= minimumSize.height ? size : nil
    }

    private func saveSize() {
        guard !readingWindow.styleMask.contains(.fullScreen) else { return }
        userDefaults.set(NSStringFromSize(readingWindow.frame.size), forKey: Self.savedSizeKey)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveSize()
    }

    func windowWillClose(_ notification: Notification) {
        saveSize()
        onClose()
    }
}
