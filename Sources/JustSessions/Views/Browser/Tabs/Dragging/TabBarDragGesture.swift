import SwiftUI

extension View {
    func tabBarDrag(
        onChanged: @escaping (_ translation: CGFloat, _ startLocation: CGPoint) -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        modifier(TabBarDragGesture(onChanged: onChanged, onEnded: onEnded))
    }
}

enum TabBarDragMetrics {
    static let minimumDistance: CGFloat = 4
    static let slideAnimation = ThemeMotion.slide
}

private struct TabBarDragGesture: ViewModifier {
    let onChanged: (CGFloat, CGPoint) -> Void
    let onEnded: () -> Void

    /// SwiftUI resets it as the drag ends, whether let go or cancelled; a gesture's own `onEnded` misses a cancel.
    @GestureState private var isDragging = false

    func body(content: Content) -> some View {
        content
            .windowMoveZoneExclusion()
            .highPriorityGesture(
                DragGesture(minimumDistance: TabBarDragMetrics.minimumDistance, coordinateSpace: .global)
                    .updating($isDragging) { _, isDragging, _ in isDragging = true }
                    .onChanged { onChanged($0.translation.width, $0.startLocation) }
            )
            .onChange(of: isDragging) { _, isDragging in
                if !isDragging { onEnded() }
            }
    }
}
