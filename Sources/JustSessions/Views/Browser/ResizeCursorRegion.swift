import AppKit
import SwiftUI

/// Shows the left/right resize cursor over its whole frame.
/// Uses an AppKit cursor rect so neighbouring views (terminal, scroll views) cannot override the cursor.
struct ResizeCursorRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeCursorRegionView {
        ResizeCursorRegionView()
    }

    func updateNSView(_ nsView: ResizeCursorRegionView, context: Context) {}
}

final class ResizeCursorRegionView: NSView {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func layout() {
        super.layout()
        window?.invalidateCursorRects(for: self)
    }

    /// Clicks and drags belong to the SwiftUI gesture on the handle, not to this view.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
