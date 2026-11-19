import SwiftUI

extension View {
    func sidebarRowDragIntoSplit(
        _ row: SidebarDraggedRow,
        titled title: String,
        in store: ConversationStore,
        fadesWhileDragged: Bool = false,
        onDropped: @escaping () -> Void
    ) -> some View {
        modifier(
            SidebarRowDragIntoSplitGesture(
                row: row,
                title: title,
                store: store,
                fadesWhileDragged: fadesWhileDragged,
                onDropped: onDropped
            ))
    }
}

private struct SidebarRowDragIntoSplitGesture: ViewModifier {
    let row: SidebarDraggedRow
    let title: String
    let store: ConversationStore
    let fadesWhileDragged: Bool
    let onDropped: () -> Void

    /// SwiftUI resets it as the drag ends, whether let go or cancelled; a gesture's own `onEnded` misses a cancel.
    @GestureState private var isDragging = false

    func body(content: Content) -> some View {
        content
            .opacity(fadesWhileDragged && isDragging ? SidebarPinDragMetrics.draggedRowOpacity : 1)
            .simultaneousGesture(
                DragGesture(minimumDistance: SidebarPinDragMetrics.minimumDistance)
                    .updating($isDragging) { _, isDragging, _ in isDragging = true }
                    .onChanged { _ in SidebarRowDragIntoSplit.shared.follow(row, titled: title, in: store) }
            )
            .onChange(of: isDragging) { _, isDragging in
                if !isDragging, SidebarRowDragIntoSplit.shared.drop() { onDropped() }
            }
            .onDisappear { SidebarRowDragIntoSplit.shared.cancel(row) }
    }
}
