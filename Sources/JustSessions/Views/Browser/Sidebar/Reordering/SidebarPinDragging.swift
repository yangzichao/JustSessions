import CoreGraphics

struct SidebarPinDragging {
    let drag: SidebarPinDrag?
    let rowFrames: SidebarRowFrames
    let onDrag: (_ rowID: SidebarRowID, _ scope: SidebarPinDrag.Scope, _ scopeRows: () -> [SidebarPinDrag.Row], _ pointer: CGPoint) -> Void
    let onDrop: () -> Void
    let onCancel: () -> Void

    func isDragging(_ rowID: SidebarRowID) -> Bool {
        drag?.draggedRowID == rowID
    }

    func ghostOffset(of rowID: SidebarRowID) -> CGFloat? {
        guard let drag, drag.draggedRowID == rowID, !drag.isPointerBesideList else { return nil }
        return drag.translation
    }

    func landingLineOffset(fromTopOf rowID: SidebarRowID) -> CGFloat? {
        guard let drag, drag.draggedRowID == rowID, let edgeY = drag.landingEdgeY,
            let draggedFrame = drag.rowFrames[rowID]
        else { return nil }
        return edgeY - draggedFrame.minY
    }
}
