import CoreGraphics

/// Where the pointer took hold of dragged tabs, which stay at that spot under it in any window: how far it was past
/// the tabs' leading edge, and how far below the window's top edge.
struct TabDragGrab: Equatable {
    let distanceFromTabsLeadingEdge: CGFloat
    let depthBelowWindowTop: CGFloat

    /// How far tabs laid out from `tabsLeadingEdge` are drawn from their place, so they stay under the pointer.
    func translation(pointerX: CGFloat, tabsLeadingEdge: CGFloat) -> CGFloat {
        pointerX - distanceFromTabsLeadingEdge - tabsLeadingEdge
    }

    /// Where the window carrying the tabs goes, in screen coordinates, with its tabs laid out from `tabsLeadingEdge`.
    func carrierWindowOrigin(pointer: CGPoint, tabsLeadingEdge: CGFloat, windowHeight: CGFloat) -> CGPoint {
        CGPoint(
            x: pointer.x - distanceFromTabsLeadingEdge - tabsLeadingEdge,
            y: pointer.y + depthBelowWindowTop - windowHeight
        )
    }
}
