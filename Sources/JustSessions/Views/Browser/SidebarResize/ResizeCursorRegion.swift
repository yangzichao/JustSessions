import AppKit
import SwiftUI

/// Shows the left/right resize cursor, or the up/down one between rows, over its whole frame through an AppKit cursor
/// rect. Only used before macOS 15, which has no SwiftUI pointer style; see `columnResizeCursor`.
struct ResizeCursorRegion: NSViewRepresentable {
    var betweenRows = false

    func makeNSView(context: Context) -> ResizeCursorRegionView {
        ResizeCursorRegionView()
    }

    func updateNSView(_ nsView: ResizeCursorRegionView, context: Context) {
        nsView.betweenRows = betweenRows
    }
}

final class ResizeCursorRegionView: NSView {
    var betweenRows = false {
        didSet { if betweenRows != oldValue { window?.invalidateCursorRects(for: self) } }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: betweenRows ? .resizeUpDown : .resizeLeftRight)
    }

    override func layout() {
        super.layout()
        window?.invalidateCursorRects(for: self)
    }

    /// Clicks and drags belong to the SwiftUI gesture on the handle, not to this view.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
