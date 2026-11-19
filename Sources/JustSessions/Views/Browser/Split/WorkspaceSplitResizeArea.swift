import SwiftUI

struct WorkspaceSplitResizeArea: View {
    @Binding var fraction: CGFloat
    let totalLength: CGFloat
    let orientation: TerminalSplit.Orientation
    let onReverse: () -> Void

    @State private var dragStartFraction: CGFloat?
    @State private var isHovering = false
    @Environment(\.tabBarTerminalPalette) private var terminalPalette

    private static let handleSize = CGSize(width: 4, height: 24)
    private static let handleColor = ThemeColor(role: .line, opacity: 0.4)

    var body: some View {
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
