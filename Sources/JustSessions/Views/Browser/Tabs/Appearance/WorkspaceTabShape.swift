import SwiftUI

struct WorkspaceTabShape: Shape {
    var cornerRadius = WorkspaceTabMetrics.cornerRadius
    var footRadius = WorkspaceTabMetrics.footRadius
    var splitSide: TerminalSplit.Side?
    var isOpenAtBottom = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if splitSide == .right {
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

struct WorkspaceTabHoverShape: Shape {
    var splitSide: TerminalSplit.Side?

    private static let cornerRadius = ThemeCornerRadius.control.rawValue

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
