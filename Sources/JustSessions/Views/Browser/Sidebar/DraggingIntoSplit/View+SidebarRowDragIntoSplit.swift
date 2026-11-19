import SwiftUI

extension View {
    /// Lets the row be dragged onto its window's terminals, to show `row` there as a tab dragged from the tab bar would;
    /// see `SidebarRowDragIntoSplit`. It drags alongside the row's other drags, such as among the pinned rows, which
    /// land nowhere once the pointer leaves the list. The highlight over the terminals names it `title`. The row fades
    /// while dragged when `fadesWhileDragged`, for a row with no other drag to fade it. `onDropped` comes once the row
    /// shows there.
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
