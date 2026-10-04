import SwiftUI

/// The divider between two panes. Drags move in global coordinates and whole points, like the sidebar's divider,
/// so neither side shakes or lands off the pixel grid.
struct WorkspacePaneDivider: View {
    let divider: WorkspacePaneGeometry.Divider
    let onFraction: (Double) -> Void

    @State private var dragStartLeadingLength: CGFloat?
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(ThemePalette.contentSurface)
            .overlay {
                if isHovering { Rectangle().fill(ThemePalette.hoverFill) }
            }
            .overlay {
                Rectangle()
                    .fill(ThemePalette.hairline)
                    .frame(
                        width: divider.isHorizontal ? 1 : nil,
                        height: divider.isHorizontal ? nil : 1
                    )
            }
            .contentShape(Rectangle())
            .paneResizeCursor(isHorizontal: divider.isHorizontal)
            .onHover { isHovering = $0 }
            .gesture(
                // Global coordinates: the divider moves with the fraction it changes, so a translation in its own
                // space would oscillate, as the sidebar divider once did.
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { gesture in
                        let startingLength = dragStartLeadingLength ?? currentLeadingLength
                        if dragStartLeadingLength == nil { dragStartLeadingLength = startingLength }
                        let translation = divider.isHorizontal ? gesture.translation.width : gesture.translation.height
                        onFraction(WorkspacePaneGeometry.fraction(
                            forLeadingLength: startingLength + translation,
                            in: divider.splitBounds,
                            isHorizontal: divider.isHorizontal
                        ))
                    }
                    .onEnded { _ in dragStartLeadingLength = nil }
            )
            .accessibilityElement()
            .accessibilityLabel("Pane divider")
            .accessibilityValue("\(Int(currentLeadingLength)) points")
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = direction == .increment ? 20 : -20
                onFraction(WorkspacePaneGeometry.fraction(
                    forLeadingLength: currentLeadingLength + step,
                    in: divider.splitBounds,
                    isHorizontal: divider.isHorizontal
                ))
            }
    }

    private var currentLeadingLength: CGFloat {
        divider.isHorizontal
            ? divider.rect.minX - divider.splitBounds.minX
            : divider.rect.minY - divider.splitBounds.minY
    }
}

private extension View {
    /// The column or row resize pointer, matching which way the divider moves.
    func paneResizeCursor(isHorizontal: Bool) -> some View {
        modifier(PaneResizeCursor(isHorizontal: isHorizontal))
    }
}

private struct PaneResizeCursor: ViewModifier {
    let isHorizontal: Bool

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.pointerStyle(isHorizontal ? .columnResize : .rowResize)
        } else {
            content.background {
                ResizeCursorRegion(cursor: isHorizontal ? .resizeLeftRight : .resizeUpDown)
            }
        }
    }
}
