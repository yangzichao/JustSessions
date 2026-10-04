import SwiftUI

/// The selected tab's outline, as in Chrome: rounded top corners, and feet that curve out at the bottom into the edge
/// below, so the tab and the terminal under it read as one surface. The feet reach `footRadius` past each side.
///
/// A split's two tabs join into one such shape, as Chrome draws them: on the side where the other tab of the split
/// meets it, a tab has a square top corner and no foot, and runs to its edge.
struct WorkspaceTabShape: Shape {
    var cornerRadius = WorkspaceTabMetrics.cornerRadius
    var footRadius = WorkspaceTabMetrics.footRadius
    /// The tab's side of its split, or nil for a tab in no split.
    var splitSide: TerminalSplit.Side?
    /// Open along the bottom, and along the side where the split's other tab joins, for stroking only the outer edge,
    /// as Chrome's `PathType::kBorder` does for a split.
    var isOpenAtBottom = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if splitSide == .right {
            // The left tab draws the joined shape's left side.
            if isOpenAtBottom {
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            } else {
                path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            }
        } else {
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
        }
        if splitSide == .left {
            // The right tab draws the joined shape's right side.
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            if !isOpenAtBottom { path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)) }
        } else {
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
        }
        if !isOpenAtBottom { path.closeSubpath() }
        return path
    }
}

/// The faint fill under the pointer on a tab that is not selected: a rounded shape inset from the tab's edges. A split's
/// two tabs light up together and join into one, as Chrome shows hover on both: each runs to the edge where the other
/// meets it, with square corners there, so only the joined shape's outer corners are rounded.
struct WorkspaceTabHoverShape: Shape {
    var splitSide: TerminalSplit.Side?

    private static let cornerRadius: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let leadingInset: CGFloat = splitSide == .right ? 0 : 2
        let trailingInset: CGFloat = splitSide == .left ? 0 : 2
        let insetRect = CGRect(
            x: rect.minX + leadingInset,
            y: rect.minY + 2,
            width: max(rect.width - leadingInset - trailingInset, 0),
            height: max(rect.height - 6, 0)
        )
        let radius = Self.cornerRadius
        switch splitSide {
        case nil:
            return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: insetRect)
        case .left:
            return UnevenRoundedRectangle(topLeadingRadius: radius, bottomLeadingRadius: radius, style: .continuous)
                .path(in: insetRect)
        case .right:
            return UnevenRoundedRectangle(bottomTrailingRadius: radius, topTrailingRadius: radius, style: .continuous)
                .path(in: insetRect)
        }
    }
}
