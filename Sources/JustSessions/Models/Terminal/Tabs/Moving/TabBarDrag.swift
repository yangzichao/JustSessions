import CoreGraphics

struct TabBarDrag<ItemID: Hashable>: Equatable {
    let draggedID: ItemID
    let itemIDs: [ItemID]
    let widths: [CGFloat]
    let spacing: CGFloat
    var translation: CGFloat = 0

    private let draggedIndex: Int
    private let leadingEdges: [CGFloat]

    init?(dragging draggedID: ItemID, among itemIDs: [ItemID], widths: [CGFloat], spacing: CGFloat) {
        guard widths.count == itemIDs.count, let draggedIndex = itemIDs.firstIndex(of: draggedID) else { return nil }
        self.draggedID = draggedID
        self.itemIDs = itemIDs
        self.widths = widths
        self.spacing = spacing
        self.draggedIndex = draggedIndex
        var leadingEdge: CGFloat = 0
        leadingEdges = widths.map { width in
            defer { leadingEdge += width + spacing }
            return leadingEdge
        }
    }

    func placesItemsAlike(_ other: TabBarDrag) -> Bool {
        draggedID == other.draggedID && itemIDs == other.itemIDs && widths == other.widths && spacing == other.spacing
            && targetIndex == other.targetIndex
    }

    var targetIndex: Int {
        let draggedLeadingEdge = leadingEdges[draggedIndex] + keptTranslation
        let draggedTrailingEdge = draggedLeadingEdge + widths[draggedIndex]
        let itemsStayingBefore = itemIDs.indices.prefix(draggedIndex).filter { middle(ofItemAt: $0) <= draggedLeadingEdge }
        let itemsPassedAfter = itemIDs.indices.suffix(from: draggedIndex + 1).filter { middle(ofItemAt: $0) < draggedTrailingEdge }
        return itemsStayingBefore.count + itemsPassedAfter.count
    }

    var orderedItemIDs: [ItemID] {
        var orderedItemIDs = itemIDs
        orderedItemIDs.remove(at: draggedIndex)
        orderedItemIDs.insert(draggedID, at: targetIndex)
        return orderedItemIDs
    }

    func offset(of itemID: ItemID) -> CGFloat {
        guard let index = itemIDs.firstIndex(of: itemID) else { return 0 }
        let targetIndex = targetIndex
        let displacement = widths[draggedIndex] + spacing
        if index == draggedIndex { return keptTranslation }
        if targetIndex <= index && index < draggedIndex { return displacement }
        if draggedIndex < index && index <= targetIndex { return -displacement }
        return 0
    }

    private var keptTranslation: CGFloat {
        let startEdge = leadingEdges[draggedIndex]
        let rowWidth = widths.reduce(0, +) + spacing * CGFloat(max(widths.count - 1, 0))
        return min(max(translation, -startEdge), rowWidth - widths[draggedIndex] - startEdge)
    }

    private func middle(ofItemAt index: Int) -> CGFloat {
        leadingEdges[index] + widths[index] / 2
    }
}
