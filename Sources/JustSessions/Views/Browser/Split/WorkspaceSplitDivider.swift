import SwiftUI

/// The gutter between a split's two panes, in the tab bar's surface like Chrome's gutter between split tabs. It has
/// its own place in the layout, so the panes' terminals never lie under it; dragging it resizes both terminals live,
/// as the sidebar's resize handle does.
struct WorkspaceSplitDivider: View {
    /// The leading pane's share of the split's width.
    @Binding var fraction: CGFloat
    /// The whole split's width, the panes' and the divider's.
    let totalWidth: CGFloat

    /// Where the divider sat as the current drag began, or nil between drags.
    @State private var dragStartFraction: CGFloat?
    @State private var isHovering = false

    var body: some View {
        // The fraction as the panes show it now: one set in a wider window may sit past where this width allows.
        let shownFraction = TerminalSplitLayout.clampedFraction(fraction, totalWidth: totalWidth)
        let paneWidths = TerminalSplitLayout.paneWidths(fraction: shownFraction, totalWidth: totalWidth)
        Rectangle()
            .fill(ThemePalette.sidebarSurface)
            .overlay {
                if isHovering { Rectangle().fill(ThemePalette.hoverFill) }
            }
            .frame(width: TerminalSplitLayout.dividerWidth)
            .contentShape(Rectangle())
            .columnResizeCursor(
                canShrink: paneWidths.leading > TerminalSplitLayout.minimumPaneWidth,
                canGrow: paneWidths.trailing > TerminalSplitLayout.minimumPaneWidth
            )
            .onHover { isHovering = $0 }
            .gesture(
                // Global coordinates, because the divider moves with the fraction it changes: a translation in its
                // own space would shrink as it slides under the pointer, pulling the panes back each event.
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
            .accessibilityLabel("Split view divider")
            .accessibilityValue(Text(verbatim: "\(Int((shownFraction * 100).rounded()))%"))
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = direction == .increment ? 0.05 : -0.05
                fraction = TerminalSplitLayout.clampedFraction(shownFraction + step, totalWidth: totalWidth)
            }
    }
}
