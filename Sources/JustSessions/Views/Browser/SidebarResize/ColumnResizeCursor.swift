import SwiftUI

extension View {
    /// Shows the column-resize pointer over a divider between two columns, such as the sidebar's edge or the gutter
    /// between split panes. When the column before the divider is as narrow or as wide as it gets, the pointer only
    /// points the way the divider can still move, like a native split view divider.
    func columnResizeCursor(canShrink: Bool, canGrow: Bool) -> some View {
        modifier(ColumnResizeCursor(canShrink: canShrink, canGrow: canGrow))
    }
}

private struct ColumnResizeCursor: ViewModifier {
    let canShrink: Bool
    let canGrow: Bool

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            // NSHostingView answers cursor updates itself and puts the arrow back, so an AppKit cursor rect
            // never shows here; the cursor has to come from SwiftUI's pointer style.
            content.pointerStyle(pointerStyle)
        } else {
            content.background { ResizeCursorRegion() }
        }
    }

    @available(macOS 15, *)
    private var pointerStyle: PointerStyle {
        switch (canShrink, canGrow) {
        case (true, false): .columnResize(directions: .leading)
        case (false, true): .columnResize(directions: .trailing)
        default: .columnResize
        }
    }
}
