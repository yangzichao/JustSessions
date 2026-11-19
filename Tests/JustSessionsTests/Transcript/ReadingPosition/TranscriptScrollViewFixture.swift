import AppKit
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
final class TranscriptScrollViewFixture {
    let positionStore = TranscriptReadingPositionStore()
    let settings: IsolatedUserDefaults
    let hostingView: NSHostingView<AnyView>
    let window: NSWindow

    init(width: CGFloat = 780, height: CGFloat = 480) throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        hostingView = NSHostingView(rootView: AnyView(EmptyView()))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
    }

    func show(
        _ conversation: Conversation, transcript: TranscriptContent, paging: TranscriptPagingModel? = nil,
        isActive: Bool = true, searchState: TranscriptSearchState = TranscriptSearchState(),
        store: ConversationStore? = nil, bookmarkState: TranscriptBookmarkState = TranscriptBookmarkState()
    ) async throws -> NSScrollView {
        hostingView.rootView = AnyView(
            TranscriptPagingTestReader(
                conversation: conversation, transcript: transcript, positionStore: positionStore, paging: paging,
                isActive: isActive, searchState: searchState, store: store, bookmarkState: bookmarkState
            ).id(conversation.id).defaultAppStorage(settings.userDefaults))
        try await settleLayout()
        return try #require(descendant(ofType: NSScrollView.self, in: hostingView))
    }

    func showReader(
        _ conversation: Conversation, matchReveal: TranscriptMatchReveal? = nil, store: ConversationStore? = nil,
        readingRequests: SessionReadingRequests? = nil
    ) {
        hostingView.rootView = AnyView(
            TranscriptView(
                conversation: conversation, readingPositionStore: positionStore, matchReveal: matchReveal,
                readingRequests: readingRequests, store: store
            ).defaultAppStorage(settings.userDefaults))
    }

    var readerScrollView: NSScrollView? {
        descendant(ofType: NSScrollView.self, in: hostingView)
    }

    var textFieldValues: [String] {
        descendants(ofType: NSTextField.self, in: hostingView).filter(\.isEditable).map(\.stringValue)
    }

    var textViews: [TranscriptTextView] {
        descendants(ofType: TranscriptTextView.self, in: hostingView)
    }

    func settleLayout() async throws {
        for _ in 0..<8 {
            hostingView.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    func waitUntil(
        stableFor stableDuration: Duration = .milliseconds(150), timeout: Duration = .seconds(120),
        _ condition: () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        var heldSince: ContinuousClock.Instant?
        while clock.now < deadline {
            hostingView.layoutSubtreeIfNeeded()
            if condition() {
                let start = heldSince ?? clock.now
                heldSince = start
                if clock.now - start >= stableDuration { return }
            } else {
                heldSince = nil
            }
            try await Task.sleep(for: .milliseconds(10))
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
    func pressButton(labeled label: String, rightAfter action: () -> Void = {}) async throws {
        turnOnEnhancedUserInterface()
        defer { restoreEnhancedUserInterface() }
        try await settleLayout()
        let button = try #require(
            accessibilityElement(labeled: label, in: hostingView),
            "No accessibility element is labeled \"\(label)\". SwiftUI builds them only after NSApp's AXEnhancedUserInterface turns on; check that setting it still works before looking for a missing button."
        )
        action()
        #expect(button.accessibilityPerformPress?() == true)
        try await settleLayout()
    }

    /// Whether VoiceOver would find an element that reads `label`, such as a bookmark's letter or a notice: an element's
    /// label, or a text's value, which SwiftUI gives no label. Like `pressButton(labeled:)`, it turns the enhanced user
    /// interface on for the search.
    func hasAccessibilityElement(labeled label: String) async throws -> Bool {
        turnOnEnhancedUserInterface()
        defer { restoreEnhancedUserInterface() }
        try await settleLayout()
        return accessibilityElement(reading: label, in: hostingView) != nil
    }

    func close() {
        hostingView.rootView = AnyView(EmptyView())
        window.close()
        settings.removeSuite()
    }

    // periphery:ignore:parameters scrollView - callers pass the reader's scroll view to read it only when it exists.
    func visiblePosition(in scrollView: NSScrollView) -> TranscriptReadingPosition? {
        descendant(ofType: TranscriptEntryGeometryView.self, in: hostingView)?.controller.currentReadingPosition()
    }

    var positionController: TranscriptScrollPositionController? {
        descendant(ofType: TranscriptEntryGeometryView.self, in: hostingView)?.controller
    }

    // periphery:ignore:parameters scrollView - callers pass the reader's scroll view to read it only when it exists.
    func visibleEntryFrames(in scrollView: NSScrollView) -> [CGRect] {
        descendant(ofType: TranscriptEntryGeometryView.self, in: hostingView)?.controller.visibleEntryFrames() ?? []
    }

    func expectedPositionForSelectedSearchMatch(in scrollView: NSScrollView, entryIndex: Int) -> TranscriptReadingPosition? {
        guard
            let textView = descendants(ofType: TranscriptTextView.self, in: hostingView)
                .first(where: { $0.selectedSearchRange != nil }),
            let range = textView.selectedSearchRange, let textContainer = textView.textContainer,
            let layoutManager = textView.layoutManager,
            let entryFrame = descendant(ofType: TranscriptEntryGeometryView.self, in: hostingView)?
                .controller.entryFrameInClipView(at: entryIndex)
        else { return nil }
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var matchRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        matchRect.origin.x += textView.textContainerOrigin.x
        matchRect.origin.y += textView.textContainerOrigin.y
        let matchFrame = textView.convert(matchRect, to: scrollView.contentView)
        return .entry(index: entryIndex, offset: max(-6, matchFrame.minY - entryFrame.minY - 60))
    }

    static func conversation(_ sessionID: String) -> Conversation {
        Conversation(
            provider: .codex, sessionID: sessionID, projectPath: "/tmp/reading-position", suggestedTitle: sessionID,
            updatedAt: .now, sourceFile: URL(fileURLWithPath: "/tmp/\(sessionID).jsonl"))
    }

    static func transcript(count: Int = 120, omittedEntryCount: Int = 0) -> TranscriptContent {
        TranscriptContent(
            entries: (0..<count).map { index in
                let text = (0..<(12 + index % 5)).map { "Message \(index + omittedEntryCount), line \($0): keep this reading position." }
                    .joined(separator: "\n")
                return TranscriptEntry(id: index, content: .assistantMessage(text), timestamp: nil, startsTurn: true)
            }, omittedEntryCount: omittedEntryCount)
    }

    static func pagedTranscript(_ contents: [TranscriptEntry.Content]) -> TranscriptContent {
        TranscriptContent(
            entries: contents.indices.map { index in
                TranscriptEntry(
                    id: TranscriptPageIdentity.entryID(record: index, part: 0), content: contents[index], timestamp: nil, startsTurn: true)
            }, omittedEntryCount: 0, usesEntryIDsForPositions: true)
    }

    private static var enhancedUserInterfaceUsers = 0
    private static var enhancedUserInterfaceBeforeUse: NSNumber?

    private func turnOnEnhancedUserInterface() {
        if Self.enhancedUserInterfaceUsers == 0 {
            Self.enhancedUserInterfaceBeforeUse =
                NSApp.perform(NSSelectorFromString("accessibilityAttributeValue:"), with: Self.enhancedUserInterface)?
                .takeUnretainedValue() as? NSNumber
            NSApp.perform(
                NSSelectorFromString("accessibilitySetValue:forAttribute:"), with: NSNumber(value: true), with: Self.enhancedUserInterface)
        }
        Self.enhancedUserInterfaceUsers += 1
    }

    private func restoreEnhancedUserInterface() {
        Self.enhancedUserInterfaceUsers -= 1
        guard Self.enhancedUserInterfaceUsers == 0 else { return }
        NSApp.perform(
            NSSelectorFromString("accessibilitySetValue:forAttribute:"),
            with: Self.enhancedUserInterfaceBeforeUse ?? NSNumber(value: false),
            with: Self.enhancedUserInterface)
    }

    private static let enhancedUserInterface = "AXEnhancedUserInterface" as NSString

    /// SwiftUI's accessibility elements are Objective-C objects without a Swift protocol conformance, so the search
    /// looks their accessibility methods up dynamically.
    private func accessibilityElement(labeled label: String, in element: AnyObject) -> AnyObject? {
        if element.accessibilityLabel?() == label { return element }
        for child in element.accessibilityChildren?() ?? [] {
            if let match = accessibilityElement(labeled: label, in: child as AnyObject) { return match }
        }
        return nil
    }

    private func accessibilityElement(reading text: String, in element: AnyObject) -> AnyObject? {
        if element.accessibilityLabel?() == text || accessibilityValue(of: element) == text { return element }
        for child in element.accessibilityChildren?() ?? [] {
            if let match = accessibilityElement(reading: text, in: child as AnyObject) { return match }
        }
        return nil
    }

    /// Read by selector: looked up dynamically, `accessibilityValue` is taken for a string, and a scroller's is a number.
    private func accessibilityValue(of element: AnyObject) -> String? {
        let selector = NSSelectorFromString("accessibilityValue")
        guard element.responds(to: selector) else { return nil }
        return element.perform(selector)?.takeUnretainedValue() as? String
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
    let store: ConversationStore?
    let bookmarkState: TranscriptBookmarkState

    var body: some View {
        TranscriptScrollView(
            conversation: conversation, transcript: paging?.transcript ?? transcript,
            positionStore: positionStore, isActive: isActive, searchState: searchState, paging: paging,
            store: store, bookmarkState: bookmarkState)
    }
}
