import AppKit
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
final class TranscriptTextSelectionFixture {
    /// A window that counts as the key window without the app being active, as the test runner never is.
    final class KeyWindow: NSWindow {
        override var isKeyWindow: Bool { true }
    }

    static let question = "Why does the sidebar redraw?"
    static let reply = """
        Intro paragraph.

        - First item
        - Second item

        | A | B |
        | --- | --- |
        | 1 | 2 |

        ```
        let x = 1
        ```
        """
    static let lastReply = "Last reply."

    private final class EventReplay {
        var events: [NSEvent] = []
    }

    let window: NSWindow
    let hostingView: NSHostingView<AnyView>
    let pasteboard = NSPasteboard.withUniqueName()
    private let replay = EventReplay()

    init(isKeyWindow: Bool = false) async throws {
        _ = NSApplication.shared
        let entries = [
            TranscriptEntry(id: 0, content: .userMessage(Self.question), timestamp: nil, startsTurn: true),
            TranscriptEntry(
                id: 1, content: .assistantMessage(Self.reply), timestamp: nil, startsTurn: true,
                markdown: PreparedTranscriptMarkdown(text: Self.reply)),
            TranscriptEntry(
                id: 2, content: .assistantMessage(Self.lastReply), timestamp: nil, startsTurn: false,
                markdown: PreparedTranscriptMarkdown(text: Self.lastReply)),
        ]
        hostingView = NSHostingView(
            rootView: AnyView(
                TranscriptScrollView(
                    conversation: TranscriptScrollViewFixture.conversation("text-selection"),
                    transcript: TranscriptContent(entries: entries, omittedEntryCount: 0),
                    positionStore: TranscriptReadingPositionStore()
                )))
        let windowClass: NSWindow.Type = isKeyWindow ? KeyWindow.self : NSWindow.self
        window = windowClass.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 900), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.orderFrontRegardless()
        for _ in 0..<8 {
            hostingView.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            try await Task.sleep(for: .milliseconds(20))
        }
        let coordinator = try coordinator
        coordinator.pasteboard = pasteboard
        coordinator.eventSource = TranscriptTextSelectionEventSource(
            startTracking: {},
            nextEvent: { [replay] _ in replay.events.isEmpty ? nil : replay.events.removeFirst() },
            stopTracking: {}
        )
    }

    func close() {
        pasteboard.releaseGlobally()
        window.close()
    }

    var textViews: [TranscriptTextView] { Self.descendants(of: hostingView) }

    var coordinator: TranscriptTextSelectionCoordinator {
        get throws { try #require(textViews.first?.selectionCoordinator) }
    }

    var selectedTexts: [String] {
        textViews.sorted {
            ($0.selectionKey ?? .init(entryIndex: 0, segmentIndex: 0)) < ($1.selectionKey ?? .init(entryIndex: 0, segmentIndex: 0))
        }
        .map { ($0.string as NSString).substring(with: $0.selectedRange()) }
        .filter { !$0.isEmpty }
    }

    func point(in view: TranscriptTextView, atCharacter offset: Int) throws -> NSPoint {
        let layoutManager = try #require(view.layoutManager)
        let textContainer = try #require(view.textContainer)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: offset, length: 1), actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += view.textContainerOrigin.x
        rect.origin.y += view.textContainerOrigin.y
        return view.convert(NSPoint(x: rect.minX + rect.width * 0.3, y: rect.midY), to: nil)
    }

    func drag(from start: NSPoint, to end: NSPoint, in view: TranscriptTextView, modifiers: NSEvent.ModifierFlags = []) throws {
        replay.events = [
            try mouseEvent(.leftMouseDragged, at: end, modifiers: modifiers), try mouseEvent(.leftMouseUp, at: end, modifiers: modifiers),
        ]
        view.mouseDown(with: try mouseEvent(.leftMouseDown, at: start, modifiers: modifiers))
    }

    func click(at point: NSPoint, in view: TranscriptTextView, modifiers: NSEvent.ModifierFlags = []) throws {
        replay.events = [try mouseEvent(.leftMouseUp, at: point, modifiers: modifiers)]
        view.mouseDown(with: try mouseEvent(.leftMouseDown, at: point, modifiers: modifiers))
    }

    func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint, modifiers: NSEvent.ModifierFlags, clickCount: Int = 1) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: clickCount, pressure: 1
            ))
    }

    private static func descendants(of view: NSView) -> [TranscriptTextView] {
        ((view as? TranscriptTextView).map { [$0] } ?? []) + view.subviews.flatMap(descendants(of:))
    }
}
