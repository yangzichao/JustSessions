import SwiftUI

/// Sizes of a split pane's outline, as Chrome's `ContentsContainerOutline` and `kSplitViewContentPadding`.
enum WorkspaceSplitPaneMetrics {
    static let outlineWidth: CGFloat = 1
    static let outlineCornerRadius: CGFloat = 8
    /// Between the outline and the terminal inside it.
    static let contentPadding: CGFloat = 4
    /// From the pane's edge to its terminal.
    static var terminalInset: CGFloat { outlineWidth + contentPadding }
}

/// The rounded outline around a split pane, as Chrome's `ContentsContainerOutline::GetPath` draws it: with a mini
/// toolbar in the pane's bottom-trailing corner, the outline turns in above the toolbar and runs down its leading side,
/// curving out into the bottom edge, so the toolbar sits in a notch of the outline. Stroked with `lineWidth`, the line
/// stays inside the pane's bounds.
struct WorkspaceSplitPaneOutlineShape: Shape {
    /// The mini toolbar's size, from its measured frame; zero for no toolbar, which draws a plain rounded rectangle.
    var toolbarSize: CGSize
    var lineWidth = WorkspaceSplitPaneMetrics.outlineWidth
    var cornerRadius = WorkspaceSplitPaneMetrics.outlineCornerRadius

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let radius = cornerRadius - lineWidth / 2
        // The notch keeps the toolbar's full corner radius, as in Chrome.
        let notchRadius = cornerRadius
        var path = Path()
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY + radius))
        path.addArc(tangent1End: CGPoint(x: bounds.minX, y: bounds.minY), tangent2End: CGPoint(x: bounds.maxX, y: bounds.minY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: bounds.maxX, y: bounds.minY), tangent2End: CGPoint(x: bounds.maxX, y: bounds.maxY), radius: radius)
        if toolbarSize.width <= 0 || toolbarSize.height <= 0 {
            path.addArc(tangent1End: CGPoint(x: bounds.maxX, y: bounds.maxY), tangent2End: CGPoint(x: bounds.minX, y: bounds.maxY), radius: radius)
        } else {
            let toolbarTop = bounds.maxY - toolbarSize.height
            let toolbarLeading = bounds.maxX - toolbarSize.width
            // Down the trailing side to the toolbar's top, then in over the toolbar.
            path.addLine(to: CGPoint(x: bounds.maxX, y: toolbarTop))
            path.addArc(
                tangent1End: CGPoint(x: bounds.maxX, y: toolbarTop + notchRadius),
                tangent2End: CGPoint(x: toolbarLeading, y: toolbarTop + notchRadius),
                radius: notchRadius
            )
            // Around the toolbar's leading top corner and down its leading side.
            path.addArc(
                tangent1End: CGPoint(x: toolbarLeading + notchRadius, y: toolbarTop + notchRadius),
                tangent2End: CGPoint(x: toolbarLeading + notchRadius, y: bounds.maxY),
                radius: notchRadius
            )
            // Out into the bottom edge.
            path.addArc(
                tangent1End: CGPoint(x: toolbarLeading + notchRadius, y: bounds.maxY),
                tangent2End: CGPoint(x: bounds.minX, y: bounds.maxY),
                radius: notchRadius
            )
        }
        path.addArc(tangent1End: CGPoint(x: bounds.minX, y: bounds.maxY), tangent2End: CGPoint(x: bounds.minX, y: bounds.minY), radius: radius)
        path.closeSubpath()
        return path
    }
}

/// The mini toolbar's own shape, which fills the pane outline's notch exactly, as Chrome clips its mini toolbar in
/// `ContentsContainerOutline::SetClipPath`: a rectangle whose top and leading sides curve in, with feet running out
/// along the pane's trailing and bottom edges.
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
    /// A split pane's outline, by Chrome's color mixer: darker around the selected tab's pane than around the other,
    /// in Chrome's greys for a light or a dark background.
    func splitPaneOutlineColor(isSelected: Bool) -> Color {
        let hexValue: UInt32 = switch (isSelected, isDark) {
        case (true, false): 0x80868B
        case (true, true): 0x9AA0A6
        case (false, false): 0xDADCE0
        case (false, true): 0x5F6368
        }
        return Color(nsColor: NSColor(hexValue: hexValue))
    }
}
