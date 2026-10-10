import Foundation

/// What the project list's rows need to drag a project or session among the pinned ones: the drag going on, where to
/// report their frames, and what to tell the list as the pointer moves and lets go.
struct SidebarPinDragging {
    let drag: SidebarPinDrag?
    let rowFrames: SidebarRowFrames
    /// Called as the pointer moves: the dragged row's id and scope, the scope's rows, asked for only as the drag
    /// begins, and where the pointer is from the top of the list.
    let onDrag: (_ rowID: String, _ scope: SidebarPinDrag.Scope, _ scopeRows: () -> [SidebarPinDrag.Row], _ pointerY: CGFloat) -> Void
    /// Called when the pointer lets go, or the drag is cancelled.
    let onDrop: () -> Void
    /// Called when the dragged row goes away mid-drag, so nothing is left fading or following a pointer.
    let onCancel: () -> Void

    func isDragging(_ rowID: String) -> Bool {
        drag?.draggedRowID == rowID
    }

    /// How far below the dragged row's top the landing line lies; nil for any other row, or while nothing would land.
    func landingLineOffset(fromTopOf rowID: String) -> CGFloat? {
        guard let drag, drag.draggedRowID == rowID, let edgeY = drag.landingEdgeY,
              let draggedFrame = drag.rowFrames[rowID] else { return nil }
        return edgeY - draggedFrame.minY
    }
}
