import SwiftUI

extension View {
    /// Follows a drag of a tab or a group along the tab bar; see `TabBarDrag`. Once the pointer has moved a few
    /// points, the drag takes over from the buttons inside, so letting go neither selects nor closes a tab, nor
    /// collapses a group, while a click still does. `onEnded` comes when the drag ends, or when it is cancelled, so a
    /// drag never stays half done. The drag moves the tab or group, not the window, though the bar is in the title bar.
    /// The drag continues wherever the pointer goes, even off the bar.
    func tabBarDrag(onChanged: @escaping (_ translation: CGFloat) -> Void, onEnded: @escaping () -> Void) -> some View {
        modifier(TabBarDragGesture(onChanged: onChanged, onEnded: onEnded))
    }
}

enum TabBarDragMetrics {
    /// How far the pointer moves before a press on a tab or group label becomes a drag.
    static let minimumDistance: CGFloat = 4
    /// How long a tab passed by the dragged one takes to slide over, and the dragged one to settle when dropped.
    static let slideAnimation: Animation = .easeOut(duration: 0.15)
}

private struct TabBarDragGesture: ViewModifier {
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    /// SwiftUI resets it as the drag ends, whether let go or cancelled; a gesture's own `onEnded` misses a cancel.
    @GestureState private var isDragging = false

    func body(content: Content) -> some View {
        content
            .windowMoveZoneExclusion()
            .highPriorityGesture(
                // Measured in the window, since the view it moves is the one it is on.
                DragGesture(minimumDistance: TabBarDragMetrics.minimumDistance, coordinateSpace: .global)
                    .updating($isDragging) { _, isDragging, _ in isDragging = true }
                    .onChanged { onChanged($0.translation.width) }
            )
            .onChange(of: isDragging) { _, isDragging in
                if !isDragging { onEnded() }
            }
    }
}
