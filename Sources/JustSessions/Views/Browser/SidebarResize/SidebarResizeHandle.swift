import AppKit
import SwiftUI

struct SidebarResizeHandle: View {
    private static let grabAreaWidth: CGFloat = 8
    private static var coordinateSpaceThatDoesNotMoveWithTheHandle: some CoordinateSpaceProtocol { .global }

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
                DragGesture(minimumDistance: 1, coordinateSpace: Self.coordinateSpaceThatDoesNotMoveWithTheHandle)
                    .onChanged { gesture in
                        let startingWidth = dragStartWidth ?? width
                        if dragStartWidth == nil { dragStartWidth = startingWidth }
                        onChange(wholePointWidthInRange(startingWidth + gesture.translation.width))
                    }
                    .onEnded { gesture in
                        onCommit(wholePointWidthInRange((dragStartWidth ?? width) + gesture.translation.width))
                        dragStartWidth = nil
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Sidebar width")
            .accessibilityValue("\(Int(width)) points")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onCommit(wholePointWidthInRange(width + 20))
                case .decrement: onCommit(wholePointWidthInRange(width - 20))
                @unknown default: break
                }
            }
    }

    private func wholePointWidthInRange(_ proposedWidth: CGFloat) -> CGFloat {
        min(max(proposedWidth.rounded(), minimumWidth), maximumWidth)
    }
}
