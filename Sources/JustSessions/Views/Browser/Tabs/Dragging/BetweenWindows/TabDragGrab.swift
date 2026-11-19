import CoreGraphics

struct TabDragGrab: Equatable {
    let distanceFromTabsLeadingEdge: CGFloat
    let depthBelowWindowTop: CGFloat

    func translation(pointerX: CGFloat, tabsLeadingEdge: CGFloat) -> CGFloat {
        pointerX - distanceFromTabsLeadingEdge - tabsLeadingEdge
    }

    func carrierWindowOrigin(pointer: CGPoint, tabsLeadingEdge: CGFloat, windowHeight: CGFloat) -> CGPoint {
        CGPoint(
            x: pointer.x - distanceFromTabsLeadingEdge - tabsLeadingEdge,
            y: pointer.y + depthBelowWindowTop - windowHeight
        )
    }
}
