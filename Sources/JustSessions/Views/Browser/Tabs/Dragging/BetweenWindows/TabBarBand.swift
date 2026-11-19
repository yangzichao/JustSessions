import CoreGraphics

struct TabBarBand {
    static let height = WorkspaceTabMetrics.topInset + WorkspaceTabMetrics.height
    static let detachDistance: CGFloat = 15

    let windowFrame: CGRect

    func takesTab(at point: CGPoint) -> Bool {
        isBetweenSides(point) && point.y <= windowFrame.maxY && point.y >= windowFrame.maxY - Self.height
    }

    func holdsTab(at point: CGPoint) -> Bool {
        isBetweenSides(point)
            && point.y <= windowFrame.maxY + Self.detachDistance
            && point.y >= windowFrame.maxY - Self.height - Self.detachDistance
    }

    private func isBetweenSides(_ point: CGPoint) -> Bool {
        point.x >= windowFrame.minX && point.x <= windowFrame.maxX
    }
}
