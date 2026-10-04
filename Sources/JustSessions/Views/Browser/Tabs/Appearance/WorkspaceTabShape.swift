import SwiftUI

/// The selected tab's outline, as in Chrome: rounded top corners, and feet that curve out at the bottom into the edge
/// below, so the tab and the terminal under it read as one surface. The feet reach `footRadius` past each side.
struct WorkspaceTabShape: Shape {
    var cornerRadius = WorkspaceTabMetrics.cornerRadius
    var footRadius = WorkspaceTabMetrics.footRadius
    /// Open along the bottom, for stroking the sides and top only.
    var isOpenAtBottom = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX - footRadius, y: rect.maxY))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.minY),
            radius: footRadius
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY),
            radius: cornerRadius
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: cornerRadius
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX + footRadius, y: rect.maxY),
            radius: footRadius
        )
        path.addLine(to: CGPoint(x: rect.maxX + footRadius, y: rect.maxY))
        if !isOpenAtBottom { path.closeSubpath() }
        return path
    }
}
