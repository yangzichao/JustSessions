import AppKit
import SwiftUI

struct SidebarResizeHandle: View {
    let width: CGFloat
    let minimumWidth: CGFloat
    let maximumWidth: CGFloat
    let onChange: (CGFloat) -> Void
    let onCommit: (CGFloat) -> Void

    @State private var dragStartWidth: CGFloat?
    @State private var isHovering = false

    var body: some View {
        // The hairline sits on the sidebar's edge and the rest of the grab area continues the detail's surface.
        Rectangle()
            .fill(ThemePalette.contentSurface)
            .overlay {
                if isHovering { Rectangle().fill(ThemePalette.hoverFill) }
            }
            .frame(width: 8)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(ThemePalette.hairline)
                    .frame(width: 1)
            }
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
