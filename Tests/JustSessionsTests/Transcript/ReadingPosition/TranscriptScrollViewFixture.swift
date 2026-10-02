import AppKit
import SwiftUI
import Testing
@testable import JustSessions

@MainActor
final class TranscriptScrollViewFixture {
    let positionStore = TranscriptReadingPositionStore()
    /// The transcript's saved settings, such as its reading width, live here instead of in the app's own settings.
    let settings: IsolatedUserDefaults
    let hostingView: NSHostingView<AnyView>
    private let window: NSWindow

    init(width: CGFloat = 780) throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 480), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
    }

    func show(_ conversation: Conversation, transcript: TranscriptContent) async throws -> NSScrollView {
        hostingView.rootView = AnyView(TranscriptScrollView(
            conversation: conversation, transcript: transcript, positionStore: positionStore
        ).id(conversation.id).defaultAppStorage(settings.userDefaults))
        try await settleLayout()
        return try #require(descendant(ofType: NSScrollView.self, in: hostingView))
    }

    func settleLayout() async throws {
        for _ in 0..<8 {
            hostingView.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    func scroll(_ scrollView: NSScrollView, to offset: CGFloat) async throws {
        NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: scrollView)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: offset))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        try await settleLayout()
    }

    func close() {
        hostingView.rootView = AnyView(EmptyView())
        window.close()
        settings.removeSuite()
    }

    func visiblePosition(in scrollView: NSScrollView) -> TranscriptReadingPosition? {
        let clipView = scrollView.contentView
        if abs(clipView.documentRect.maxY - clipView.bounds.maxY) < 2 { return .bottom }
        let markers = descendants(ofType: TranscriptEntryPositionMarkerView.self, in: hostingView)
        let visibleMarkers = markers.map { ($0.entryIndex, $0.convert($0.bounds, to: clipView)) }
            .filter { $0.1.maxY > clipView.bounds.minY && $0.1.minY < clipView.bounds.maxY }
        guard let (index, frame) = visibleMarkers.min(by: { $0.1.minY < $1.1.minY }) else { return nil }
        return .entry(index: index, offset: clipView.bounds.minY - frame.minY)
    }

    /// The frames of the entries on screen, in the scroll view's visible area. Entries fill the transcript column's
    /// width; entries scrolled out of sight can keep an earlier layout, so they are left out.
    func visibleEntryFrames(in scrollView: NSScrollView) -> [CGRect] {
        let clipView = scrollView.contentView
        return descendants(ofType: TranscriptEntryPositionMarkerView.self, in: hostingView)
            .map { $0.convert($0.bounds, to: clipView) }
            .filter { $0.intersects(clipView.bounds) }
    }

    static func conversation(_ sessionID: String) -> Conversation {
        Conversation(provider: .codex, sessionID: sessionID, projectPath: "/tmp/reading-position", suggestedTitle: sessionID,
                     updatedAt: .now, sourceFile: URL(fileURLWithPath: "/tmp/\(sessionID).jsonl"))
    }

    static func transcript(count: Int = 120, omittedEntryCount: Int = 0) -> TranscriptContent {
        TranscriptContent(entries: (0..<count).map { index in
            let text = (0..<(12 + index % 5)).map { "Message \(index + omittedEntryCount), line \($0): keep this reading position." }.joined(separator: "\n")
            return TranscriptEntry(id: index, content: .assistantMessage(text), timestamp: nil, startsTurn: true)
        }, omittedEntryCount: omittedEntryCount)
    }

    private func descendant<ViewType: NSView>(ofType type: ViewType.Type, in view: NSView) -> ViewType? {
        if let match = view as? ViewType { return match }
        for subview in view.subviews {
            if let match = descendant(ofType: type, in: subview) { return match }
        }
        return nil
    }

    private func descendants<ViewType: NSView>(ofType type: ViewType.Type, in view: NSView) -> [ViewType] {
        (view as? ViewType).map { [$0] } ?? view.subviews.flatMap { descendants(ofType: type, in: $0) }
    }
}
