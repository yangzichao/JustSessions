import SwiftUI

extension View {
    func tabBarDragShift<ItemID: Hashable>(of itemID: ItemID, in display: TabBarDragDisplay<ItemID>?) -> some View {
        modifier(TabBarDragShift(itemID: itemID, display: display))
    }
}

private struct TabBarDragShift<ItemID: Hashable>: ViewModifier {
    let itemID: ItemID
    let display: TabBarDragDisplay<ItemID>?

    func body(content: Content) -> some View {
        let drag = display?.drag
        let isDragged = drag?.draggedID == itemID
        content
            .offset(x: drag?.offset(of: itemID) ?? 0)
            .animation(isDragged ? nil : TabBarDragMetrics.slideAnimation, value: drag?.targetIndex)
            .zIndex(isDragged ? 1 : 0)
    }
}
