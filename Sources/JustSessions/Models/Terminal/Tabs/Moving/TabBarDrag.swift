import CoreGraphics

/// A drag along the tab bar, of a tab or a split's two tabs among their group's tabs, or of a group among the groups,
/// placed as in a browser's tab strip: the dragged item follows the pointer, kept within the row of items, and passes
/// a neighbor once it covers half of it; the neighbor then slides over into the place it left. The items keep their places in the layout until the drop; each is only drawn shifted, by its
/// `offset(of:)`. Worked out on the items' widths as the drag began, so nothing moves under the pointer mid-drag.
struct TabBarDrag<ItemID: Hashable>: Equatable {
    let draggedID: ItemID
    /// Every item in the row, the dragged one among them, in order as the drag began.
    let itemIDs: [ItemID]
    /// Each item's width, in the order of `itemIDs`.
    let widths: [CGFloat]
    /// The space between one item and the next.
    let spacing: CGFloat
    /// How far the pointer has moved along the bar since the drag began, rightward positive.
    var translation: CGFloat = 0

    private let draggedIndex: Int

    /// Nil unless the dragged item is in the row and every item has a width.
    init?(dragging draggedID: ItemID, among itemIDs: [ItemID], widths: [CGFloat], spacing: CGFloat) {
        guard widths.count == itemIDs.count, let draggedIndex = itemIDs.firstIndex(of: draggedID) else { return nil }
        self.draggedID = draggedID
        self.itemIDs = itemIDs
        self.widths = widths
        self.spacing = spacing
        self.draggedIndex = draggedIndex
    }

    /// Where the dragged item lands, among every item: past each item whose middle its leading edge, on the way left,
    /// or its trailing edge, on the way right, has passed. An edge rather than its middle, so an item wider than a
    /// neighbor at the end of the row still passes it before reaching the end.
    var targetIndex: Int {
        let draggedLeadingEdge = leadingEdge(ofItemAt: draggedIndex) + keptTranslation
        let draggedTrailingEdge = draggedLeadingEdge + widths[draggedIndex]
        let itemsStayingBefore = itemIDs.indices.prefix(draggedIndex).filter { middle(ofItemAt: $0) <= draggedLeadingEdge }
        let itemsPassedAfter = itemIDs.indices.suffix(from: draggedIndex + 1).filter { middle(ofItemAt: $0) < draggedTrailingEdge }
        return itemsStayingBefore.count + itemsPassedAfter.count
    }

    /// The items in the order they show while the drag goes on, the dragged one at `targetIndex`.
    var orderedItemIDs: [ItemID] {
        var orderedItemIDs = itemIDs
        orderedItemIDs.remove(at: draggedIndex)
        orderedItemIDs.insert(draggedID, at: targetIndex)
        return orderedItemIDs
    }

    /// How far the item is drawn from its place as the drag began: the dragged one as far as the pointer has moved,
    /// and each one it has passed by the dragged one's width and the spacing, the other way.
    func offset(of itemID: ItemID) -> CGFloat {
        guard let index = itemIDs.firstIndex(of: itemID) else { return 0 }
        let targetIndex = targetIndex
        let displacement = widths[draggedIndex] + spacing
        if index == draggedIndex { return keptTranslation }
        // Passed on its way left, so it slides right; or on its way right, so it slides left.
        if targetIndex <= index && index < draggedIndex { return displacement }
        if draggedIndex < index && index <= targetIndex { return -displacement }
        return 0
    }

    /// The translation held so the dragged item goes no further than either end of the row.
    private var keptTranslation: CGFloat {
        let startEdge = leadingEdge(ofItemAt: draggedIndex)
        let rowWidth = widths.reduce(0, +) + spacing * CGFloat(max(widths.count - 1, 0))
        return min(max(translation, -startEdge), rowWidth - widths[draggedIndex] - startEdge)
    }

    /// The item's leading edge as the drag began, from the row's leading edge.
    private func leadingEdge(ofItemAt index: Int) -> CGFloat {
        widths.prefix(index).reduce(0, +) + spacing * CGFloat(index)
    }

    private func middle(ofItemAt index: Int) -> CGFloat {
        leadingEdge(ofItemAt: index) + widths[index] / 2
    }
}
