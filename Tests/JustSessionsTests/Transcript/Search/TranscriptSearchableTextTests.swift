import AppKit
import SwiftUI
import Testing
@testable import JustSessions

@MainActor
struct TranscriptSearchableTextTests {
    /// Outside Find, and for a query the block lacks, the block is SwiftUI text; for a match, it is the AppKit view that
    /// draws highlights.
    @Test(arguments: [("", false), ("absent", false), ("needle", true)])
    func drawsHighlightsOnlyForAMatch(query: String, isHighlighted: Bool) {
        _ = NSApplication.shared
        let hostingView = NSHostingView(rootView: TranscriptSearchableText(source: AttributedString("Find the needle here"), fontSize: 13)
            .environment(\.transcriptSearchContext, TranscriptSearchContext(query: query)))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 120), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()

        #expect(Self.containsSearchTextView(hostingView) == isHighlighted)
        window.close()
    }

    private static func containsSearchTextView(_ view: NSView) -> Bool {
        view is TranscriptSearchTextView || view.subviews.contains(where: containsSearchTextView)
    }
}
