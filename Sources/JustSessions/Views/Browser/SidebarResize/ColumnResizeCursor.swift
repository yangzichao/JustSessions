import SwiftUI

extension View {
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
