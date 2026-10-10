import SwiftUI

extension ConversationSidebarView {
    var pinDragging: SidebarPinDragging {
        SidebarPinDragging(
            drag: pinDrag,
            rowFrames: sidebarRowFrames,
            onDrag: followPinDrag,
            onDrop: dropPinDrag,
            onCancel: { pinDrag = nil }
        )
    }

    /// Starts a drag of the row among its scope's rows as they are now, or follows the pointer once it has started.
    private func followPinDrag(
        of rowID: String,
        in scope: SidebarPinDrag.Scope,
        scopeRows: () -> [SidebarPinDrag.Row],
        pointerY: CGFloat
    ) {
        if pinDrag?.draggedRowID != rowID {
            pinDrag = SidebarPinDrag(
                scope: scope,
                dragging: rowID,
                rows: scopeRows(),
                rowFrames: sidebarRowFrames.framesByRowID,
                scopeBottom: scopeBottom(of: scope),
                pointerY: pointerY
            )
        }
        pinDrag?.pointerY = pointerY
    }

    /// The bottom of the host's last project, or of the project's last session.
    private func scopeBottom(of scope: SidebarPinDrag.Scope) -> CGFloat? {
        switch scope {
        case .projects(let host):
            hostSections.first { $0.host == host }?.projects.last.flatMap { sidebarRowFrames.bottom(ofProject: $0.id) }
        case .sessions(let projectPath):
            sidebarRowFrames.bottom(ofProject: projectPath)
        }
    }

    /// Pins the dragged project or session where it was let go, unless it went away meanwhile.
    private func dropPinDrag() {
        guard let pinDrag else { return }
        withAnimation(SidebarPinDragMetrics.dropAnimation) {
            if let pinID = pinDrag.draggedPinID, let placement = pinDrag.placement {
                switch pinDrag.scope {
                case .projects:
                    if projects.contains(where: { $0.id == pinID }) { store.movePinnedProject(pinID, to: placement) }
                case .sessions:
                    if store.conversation(withID: pinID) != nil { store.movePinnedConversation(pinID, to: placement) }
                }
            }
            self.pinDrag = nil
        }
    }
}
