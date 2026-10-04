import SwiftUI

/// The resize area between a split's two panes, as Chrome's: a band in the split area's color with a small pill handle
/// in its middle, which shows while the pointer is over the band or it is dragged. It has its own place in the layout,
/// so the panes' terminals never lie under it; dragging it resizes both terminals live, as the sidebar's resize handle
/// does.
struct WorkspaceSplitResizeArea: View {
    /// The left pane's share of the width the panes share.
    @Binding var fraction: CGFloat
    /// The whole split area's width.
    let totalWidth: CGFloat

    /// Where the resize area sat as the current drag began, or nil between drags.
    @State private var dragStartFraction: CGFloat?
    @State private var isHovering = false
    @Environment(\.tabBarTerminalPalette) private var terminalPalette

    /// Chrome's hover handle: 4 by 24 points, with corners of 2.
    private static let handleSize = CGSize(width: 4, height: 24)
    private static let handleCornerRadius: CGFloat = 2
    /// The app's line color at this opacity reads, on the terminal's background, about as strongly as Chrome's grey
    /// handle on its toolbar.
    private static let handleColor = ThemeColor(role: .line, opacity: 0.4)

    var body: some View {
        // The fraction as the panes show it now: one set in a wider window may sit past where this width allows.
        let shownFraction = TerminalSplitLayout.clampedFraction(fraction, totalWidth: totalWidth)
        let paneWidths = TerminalSplitLayout.paneWidths(fraction: shownFraction, totalWidth: totalWidth)
        Rectangle()
            .fill(terminalPalette.backgroundColor)
            .overlay {
                if isHovering || dragStartFraction != nil {
                    RoundedRectangle(cornerRadius: Self.handleCornerRadius)
                        .fill(Self.handleColor)
                        .frame(width: Self.handleSize.width, height: Self.handleSize.height)
                        // The line color as it reads on the terminal's background, not the window's.
                        .environment(\.colorScheme, terminalPalette.colorScheme)
                }
            }
            .contentShape(Rectangle())
            .columnResizeCursor(
                canShrink: paneWidths.leading > TerminalSplitLayout.minimumPaneWidth,
                canGrow: paneWidths.trailing > TerminalSplitLayout.minimumPaneWidth
            )
            .onHover { isHovering = $0 }
            .gesture(
                // Global coordinates, because the area moves with the fraction it changes: a translation in its own
                // space would shrink as it slides under the pointer, pulling the panes back each event.
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { gesture in
                        let startFraction = dragStartFraction ?? shownFraction
                        if dragStartFraction == nil { dragStartFraction = startFraction }
                        fraction = TerminalSplitLayout.fraction(
                            startingAt: startFraction,
                            draggedBy: gesture.translation.width,
                            totalWidth: totalWidth
                        )
                    }
                    .onEnded { _ in dragStartFraction = nil }
            )
            .accessibilityElement()
            .accessibilityLabel("Split View Resize Handle (draggable)")
            .accessibilityValue(Text(verbatim: "\(Int((shownFraction * 100).rounded()))%"))
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = direction == .increment ? 0.05 : -0.05
                fraction = TerminalSplitLayout.clampedFraction(shownFraction + step, totalWidth: totalWidth)
            }
    }
}
