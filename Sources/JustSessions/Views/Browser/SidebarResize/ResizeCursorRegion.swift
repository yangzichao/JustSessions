import AppKit
import SwiftUI

/// Shows a resize cursor over its whole frame through an AppKit cursor rect.
/// Only used before macOS 15, which has no SwiftUI pointer style; see `sidebarResizeCursor`.
struct ResizeCursorRegion: NSViewRepresentable {
    var cursor: NSCursor = .resizeLeftRight

    func makeNSView(context: Context) -> ResizeCursorRegionView {
        let view = ResizeCursorRegionView()
        view.cursor = cursor
        return view
    }

    func updateNSView(_ nsView: ResizeCursorRegionView, context: Context) {
        nsView.cursor = cursor
    }
}

final class ResizeCursorRegionView: NSView {
    var cursor: NSCursor = .resizeLeftRight {
        didSet { window?.invalidateCursorRects(for: self) }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: cursor)
    }

    override func layout() {
        super.layout()
        window?.invalidateCursorRects(for: self)
    }

    /// Clicks and drags belong to the SwiftUI gesture on the handle, not to this view.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
