import AppKit
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
struct TranscriptTextBlockTests {
    @Test(arguments: [("", false), ("absent", false), ("needle", true)])
    func drawsHighlightsOnlyForAMatch(query: String, isHighlighted: Bool) throws {
        _ = NSApplication.shared
        let hostingView = NSHostingView(
            rootView: TranscriptTextBlock(source: AttributedString("Find the needle here"), style: TranscriptTextStyle(fontSize: 13))
                .environment(\.transcriptSearchContext, TranscriptSearchContext(query: query)))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 120), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        defer { window.close() }

        let textView = try #require(Self.textView(in: hostingView))
        let needle = (textView.string as NSString).range(of: "needle")
        #expect(textView.string == "Find the needle here")
        #expect((textView.textStorage?.attribute(.backgroundColor, at: needle.location, effectiveRange: nil) != nil) == isHighlighted)
    }

    static func textView(in view: NSView) -> TranscriptTextView? {
        if let textView = view as? TranscriptTextView { return textView }
        return view.subviews.lazy.compactMap(textView(in:)).first
    }
}
