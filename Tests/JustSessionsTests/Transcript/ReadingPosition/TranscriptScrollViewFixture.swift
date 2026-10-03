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

    init(width: CGFloat = 780, height: CGFloat = 480) throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
    }

    func show(
        _ conversation: Conversation, transcript: TranscriptContent, paging: TranscriptPagingModel? = nil,
        isActive: Bool = true, searchState: TranscriptSearchState = TranscriptSearchState()
    ) async throws -> NSScrollView {
        hostingView.rootView = AnyView(TranscriptPagingTestReader(
            conversation: conversation, transcript: transcript, positionStore: positionStore, paging: paging,
            isActive: isActive, searchState: searchState
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

    /// Presses a toolbar button the way VoiceOver does, through the hosting view's accessibility elements. SwiftUI only
    /// builds those elements while an assistive app has turned on the app's enhanced user interface, so the press turns
    /// it on, then restores its earlier value afterward. The attribute accessors exist only in the deprecated informal
    /// accessibility API; calling them by selector keeps the build free of deprecation warnings.
    ///
    /// The enhanced user interface is app-wide, and other main-actor tests can run while the press waits for layout.
    /// They only see SwiftUI build its accessibility elements, but two presses must not overlap: the first to finish
    /// would turn the setting off while the other still searches. Call this only from one test at a time.
    func pressButton(labeled label: String) async throws {
        let getValue = NSSelectorFromString("accessibilityAttributeValue:")
        let setValue = NSSelectorFromString("accessibilitySetValue:forAttribute:")
        let enhancedUserInterface = "AXEnhancedUserInterface" as NSString
        let earlierValue = NSApp.perform(getValue, with: enhancedUserInterface)?.takeUnretainedValue() as? NSNumber
        NSApp.perform(setValue, with: NSNumber(value: true), with: enhancedUserInterface)
        defer { NSApp.perform(setValue, with: earlierValue ?? NSNumber(value: false), with: enhancedUserInterface) }
        try await settleLayout()
        let button = try #require(
            accessibilityElement(labeled: label, in: hostingView),
            "No accessibility element is labeled \"\(label)\". SwiftUI builds them only after NSApp's AXEnhancedUserInterface turns on; check that setting it still works before looking for a missing button."
        )
        #expect(button.accessibilityPerformPress?() == true)
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

    /// SwiftUI's accessibility elements are Objective-C objects without a Swift protocol conformance, so the search
    /// looks their accessibility methods up dynamically.
    private func accessibilityElement(labeled label: String, in element: AnyObject) -> AnyObject? {
        if element.accessibilityLabel?() == label { return element }
        for child in element.accessibilityChildren?() ?? [] {
            if let match = accessibilityElement(labeled: label, in: child as AnyObject) { return match }
        }
        return nil
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

private struct TranscriptPagingTestReader: View {
    let conversation: Conversation
    let transcript: TranscriptContent
    let positionStore: TranscriptReadingPositionStore
    let paging: TranscriptPagingModel?
    let isActive: Bool
    let searchState: TranscriptSearchState

    var body: some View {
        TranscriptScrollView(conversation: conversation, transcript: paging?.transcript ?? transcript,
                             positionStore: positionStore, isActive: isActive, searchState: searchState, paging: paging)
    }
}
