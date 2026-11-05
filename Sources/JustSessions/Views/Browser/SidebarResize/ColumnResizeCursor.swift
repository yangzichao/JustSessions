import SwiftUI

extension View {
    /// Shows the column-resize pointer over a divider between two columns, such as the sidebar's edge or the gutter
    /// between split panes, or the row-resize pointer over one between two rows, such as the gutter between stacked split
    /// panes. When the column or row before the divider is as small or as large as it gets, the pointer only points the
    /// way the divider can still move, like a native split view divider.
    func columnResizeCursor(canShrink: Bool, canGrow: Bool, betweenRows: Bool = false) -> some View {
        modifier(ColumnResizeCursor(canShrink: canShrink, canGrow: canGrow, betweenRows: betweenRows))
    }
}

private struct ColumnResizeCursor: ViewModifier {
    let canShrink: Bool
    let canGrow: Bool
    let betweenRows: Bool

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            // NSHostingView answers cursor updates itself and puts the arrow back, so an AppKit cursor rect
            // never shows here; the cursor has to come from SwiftUI's pointer style.
            content.pointerStyle(pointerStyle)
        } else {
            content.background { ResizeCursorRegion(betweenRows: betweenRows) }
        }
    }

    @available(macOS 15, *)
    private var pointerStyle: PointerStyle {
        if betweenRows {
            switch (canShrink, canGrow) {
            case (true, false): return .rowResize(directions: .up)
            case (false, true): return .rowResize(directions: .down)
            default: return .rowResize
            }
        }
        switch (canShrink, canGrow) {
        case (true, false): return .columnResize(directions: .leading)
        case (false, true): return .columnResize(directions: .trailing)
        default: return .columnResize
        }
    }
}
