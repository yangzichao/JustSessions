import AppKit
import SwiftUI

/// Shows the left/right resize cursor over its whole frame through an AppKit cursor rect.
/// Only used before macOS 15, which has no SwiftUI pointer style; see `sidebarResizeCursor`.
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
