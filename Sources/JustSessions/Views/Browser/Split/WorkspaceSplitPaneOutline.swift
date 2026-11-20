import SwiftUI

enum WorkspaceSplitPaneMetrics {
    static let outlineWidth: CGFloat = 1
    static let outlineCornerRadius = ThemeCornerRadius.card.rawValue
    static let contentPadding: CGFloat = 4
    static var terminalInset: CGFloat { outlineWidth + contentPadding }
    static let miniToolbarButtonSize: CGFloat = 20
    static let miniToolbarContentPadding: CGFloat = 4
    static var miniToolbarHeight: CGFloat {
        outlineCornerRadius + miniToolbarContentPadding + miniToolbarButtonSize + outlineWidth
    }
    static var terminalInsets: EdgeInsets {
        EdgeInsets(top: terminalInset, leading: terminalInset, bottom: miniToolbarHeight, trailing: terminalInset)
    }
}

struct WorkspaceSplitPaneOutlineShape: Shape {
    var miniToolbarSize: CGSize?
    var lineWidth = WorkspaceSplitPaneMetrics.outlineWidth
    var cornerRadius = WorkspaceSplitPaneMetrics.outlineCornerRadius

    private var miniToolbarSizeToNotchAround: CGSize? {
        guard let miniToolbarSize, miniToolbarSize.width > 0, miniToolbarSize.height > 0 else { return nil }
        return miniToolbarSize
    }

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let radius = cornerRadius - lineWidth / 2
        let notchRadius = cornerRadius
        var path = Path()
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY + radius))
        path.addArc(
            tangent1End: CGPoint(x: bounds.minX, y: bounds.minY), tangent2End: CGPoint(x: bounds.maxX, y: bounds.minY), radius: radius)
        path.addArc(
            tangent1End: CGPoint(x: bounds.maxX, y: bounds.minY), tangent2End: CGPoint(x: bounds.maxX, y: bounds.maxY), radius: radius)
        if let toolbarSize = miniToolbarSizeToNotchAround {
            let toolbarTop = bounds.maxY - toolbarSize.height
            let toolbarLeading = bounds.maxX - toolbarSize.width
            path.addLine(to: CGPoint(x: bounds.maxX, y: toolbarTop))
            path.addArc(
                tangent1End: CGPoint(x: bounds.maxX, y: toolbarTop + notchRadius),
                tangent2End: CGPoint(x: toolbarLeading, y: toolbarTop + notchRadius),
                radius: notchRadius
            )
            path.addArc(
                tangent1End: CGPoint(x: toolbarLeading + notchRadius, y: toolbarTop + notchRadius),
                tangent2End: CGPoint(x: toolbarLeading + notchRadius, y: bounds.maxY),
                radius: notchRadius
            )
            path.addArc(
                tangent1End: CGPoint(x: toolbarLeading + notchRadius, y: bounds.maxY),
                tangent2End: CGPoint(x: bounds.minX, y: bounds.maxY),
                radius: notchRadius
            )
        } else {
            path.addArc(
                tangent1End: CGPoint(x: bounds.maxX, y: bounds.maxY), tangent2End: CGPoint(x: bounds.minX, y: bounds.maxY), radius: radius)
        }
        path.addArc(
            tangent1End: CGPoint(x: bounds.minX, y: bounds.maxY), tangent2End: CGPoint(x: bounds.minX, y: bounds.minY), radius: radius)
        path.closeSubpath()
        return path
    }
}

struct WorkspaceSplitMiniToolbarShape: Shape {
    var lineWidth = WorkspaceSplitPaneMetrics.outlineWidth
    var cornerRadius = WorkspaceSplitPaneMetrics.outlineCornerRadius

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let radius = cornerRadius - lineWidth / 2
        var path = Path()
        path.move(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addArc(
            tangent1End: CGPoint(x: bounds.maxX, y: bounds.minY + radius),
            tangent2End: CGPoint(x: bounds.minX, y: bounds.minY + radius),
            radius: radius
        )
        path.addArc(
            tangent1End: CGPoint(x: bounds.minX + radius, y: bounds.minY + radius),
            tangent2End: CGPoint(x: bounds.minX + radius, y: bounds.maxY),
            radius: radius
        )
        path.addArc(
            tangent1End: CGPoint(x: bounds.minX + radius, y: bounds.maxY),
            tangent2End: CGPoint(x: bounds.minX, y: bounds.maxY),
            radius: radius
        )
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }
}

extension TerminalPalette {
    func splitPaneOutlineColor(isSelected: Bool) -> Color {
        let hexValue: UInt32 =
            switch (isSelected, isDark) {
            case (true, false): 0x80868B
            case (true, true): 0x9AA0A6
            case (false, false): 0xDADCE0
            case (false, true): 0x5F6368
            }
        return Color(nsColor: NSColor(hexValue: hexValue))
    }
}
