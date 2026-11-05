import SwiftUI

/// The resize area between a split's two panes, as Chrome's: a band in the split area's color with a small pill handle
/// in its middle, which shows while the pointer is over the band or it is dragged. It has its own place in the layout,
/// so the panes' terminals never lie under it; dragging it resizes both terminals live, as the sidebar's resize handle
/// does, snapping them even near the middle. Double-clicking it reverses the split's views, as in Chrome. Between
/// stacked panes it runs across the area and drags up and down.
struct WorkspaceSplitResizeArea: View {
    /// The first pane's share of the length the panes share.
    @Binding var fraction: CGFloat
    /// The whole split area's width side by side, or its height stacked.
    let totalLength: CGFloat
    let orientation: TerminalSplit.Orientation
    let onReverse: () -> Void

    /// Where the resize area sat as the current drag began, or nil between drags.
    @State private var dragStartFraction: CGFloat?
    @State private var isHovering = false
    @Environment(\.tabBarTerminalPalette) private var terminalPalette

    /// Chrome's hover handle: 4 by 24 points, with round ends, lying across stacked panes.
    private static let handleSize = CGSize(width: 4, height: 24)
    /// The app's line color at this opacity reads, on the terminal's background, about as strongly as Chrome's grey
    /// handle on its toolbar.
    private static let handleColor = ThemeColor(role: .line, opacity: 0.4)

    var body: some View {
        // The fraction as the panes show it now: one set in a larger window may sit past where this size allows.
        let shownFraction = TerminalSplitLayout.clampedFraction(fraction, totalLength: totalLength, orientation: orientation)
        let paneLengths = TerminalSplitLayout.paneLengths(fraction: shownFraction, totalLength: totalLength, orientation: orientation)
        let minimumLength = TerminalSplitLayout.minimumPaneLength(orientation)
        let isStacked = orientation == .stacked
        Rectangle()
            .fill(terminalPalette.backgroundColor)
            .overlay {
                if isHovering || dragStartFraction != nil {
                    Capsule()
                        .fill(Self.handleColor)
                        .frame(
                            width: isStacked ? Self.handleSize.height : Self.handleSize.width,
                            height: isStacked ? Self.handleSize.width : Self.handleSize.height
                        )
                        // The line color as it reads on the terminal's background, not the window's.
                        .environment(\.colorScheme, terminalPalette.colorScheme)
                }
            }
            .contentShape(Rectangle())
            .columnResizeCursor(
                canShrink: paneLengths.leading > minimumLength,
                canGrow: paneLengths.trailing > minimumLength,
                betweenRows: isStacked
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
                            draggedBy: isStacked ? gesture.translation.height : gesture.translation.width,
                            totalLength: totalLength,
                            orientation: orientation
                        )
                    }
                    .onEnded { _ in dragStartFraction = nil }
            )
            .onTapGesture(count: 2, perform: onReverse)
            .accessibilityElement()
            .accessibilityLabel("Split View Resize Handle (draggable)")
            .accessibilityValue(Text(verbatim: "\(Int((shownFraction * 100).rounded()))%"))
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = direction == .increment ? 0.05 : -0.05
                fraction = TerminalSplitLayout.clampedFraction(shownFraction + step, totalLength: totalLength, orientation: orientation)
            }
    }
}
