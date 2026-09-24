import AppKit
import SwiftUI

struct SidebarResizeHandle: View {
    let width: CGFloat
    let maximumWidth: CGFloat
    let onChange: (CGFloat) -> Void
    let onCommit: (CGFloat) -> Void

    @State private var dragStartWidth: CGFloat?
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(isHovering ? Color.accentColor.opacity(0.12) : Color.clear)
            .frame(width: 8)
            .overlay {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                (hovering ? NSCursor.resizeLeftRight : NSCursor.arrow).set()
            }
            .gesture(
                DragGesture(minimumDistance: 1)
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

    private func clamped(_ proposedWidth: CGFloat) -> CGFloat {
        min(max(proposedWidth, 200), maximumWidth)
    }
}
