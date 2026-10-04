import AppKit
import SwiftUI

/// The grab strip between a split's two panes. It is an AppKit view so that it sits above the terminals'
/// views and takes the drag and the resize cursor before they can; the thin line itself is drawn by the
/// detail view underneath.
struct WorkspaceSplitDivider: NSViewRepresentable {
    /// Called with the pointer's horizontal travel since the drag began, for each movement.
    let onDragBegan: () -> Void
    let onDragMoved: (CGFloat) -> Void

    func makeNSView(context: Context) -> SplitDividerStripView {
        let view = SplitDividerStripView()
        view.onDragBegan = onDragBegan
        view.onDragMoved = onDragMoved
        return view
    }

    func updateNSView(_ view: SplitDividerStripView, context: Context) {
        view.onDragBegan = onDragBegan
        view.onDragMoved = onDragMoved
    }

    final class SplitDividerStripView: NSView {
        var onDragBegan: () -> Void = {}
        var onDragMoved: (CGFloat) -> Void = { _ in }
        private var dragStartX: CGFloat = 0

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .resizeLeftRight)
        }

        override func mouseDown(with event: NSEvent) {
            dragStartX = event.locationInWindow.x
            onDragBegan()
        }

        override func mouseDragged(with event: NSEvent) {
            onDragMoved(event.locationInWindow.x - dragStartX)
        }
    }
}
