import AppKit
import SwiftUI

/// Where the sidebar's edge is grabbed to resize it: the divider and a few points of the detail past it. It draws
/// nothing until the pointer is over it, so the detail shows through.
struct SidebarResizeHandle: View {
    /// Narrower than the tab bar's and the terminal's leading margins, so it stays off the first tab and the
    /// terminal's text.
    private static let grabAreaWidth: CGFloat = 8

    let width: CGFloat
    let minimumWidth: CGFloat
    let maximumWidth: CGFloat
    let onChange: (CGFloat) -> Void
    let onCommit: (CGFloat) -> Void

    @State private var dragStartWidth: CGFloat?
    @State private var isHovering = false

    var body: some View {
        Color.clear
            .overlay {
                if isHovering { Rectangle().fill(ThemePalette.hoverFill) }
            }
            .frame(width: Self.grabAreaWidth)
            .ignoresSafeArea(edges: .top)
            .contentShape(Rectangle())
            .columnResizeCursor(canShrink: width > minimumWidth, canGrow: width < maximumWidth)
            .onHover { isHovering = $0 }
            .gesture(
                // Global coordinates, because the handle itself moves with the width it changes: a translation in
                // the handle's own space would shrink as the handle slides under the cursor, pulling the width
                // back each event and shaking both sides of the divider.
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { gesture in
                        let startingWidth = dragStartWidth ?? width
                        if dragStartWidth == nil { dragStartWidth = startingWidth }
                        onChange(clamped(startingWidth + gesture.translation.width))
                    }
                    .onEnded { gesture in
                        onCommit(clamped((dragStartWidth ?? width) + gesture.translation.width))
                        dragStartWidth = nil
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Sidebar width")
            .accessibilityValue("\(Int(width)) points")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onCommit(clamped(width + 20))
                case .decrement: onCommit(clamped(width - 20))
                @unknown default: break
                }
            }
    }

    /// Whole points, like a native split view divider: a drag's fractional positions would land the hairline and
    /// every row's text on sub-pixel offsets, shimmering on each mouse movement, and relayout the sidebar for
    /// width changes too small to see.
    private func clamped(_ proposedWidth: CGFloat) -> CGFloat {
        min(max(proposedWidth.rounded(), minimumWidth), maximumWidth)
    }
}
