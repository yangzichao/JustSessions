import SwiftUI

/// What sits over a split pane, as Chrome draws each view of a split: a rounded outline just inside the pane's edges,
/// darker around the selected tab's pane, notched around the mini toolbar in its bottom-trailing corner. The outline
/// lets clicks through to the terminal; the toolbar takes its own.
struct WorkspaceSplitPaneOverlay: View {
    @ObservedObject var session: TerminalSession
    /// The pane's tab is the selected one.
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @Environment(\.tabBarTerminalPalette) private var terminalPalette
    /// The mini toolbar's size, which the outline's notch follows.
    @State private var toolbarSize: CGSize = .zero

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            WorkspaceSplitMiniToolbar(session: session, showsTabDetails: !isSelected, onSelect: onSelect, onClose: onClose)
                .onGeometryChange(for: CGSize.self, of: \.size) { toolbarSize = $0 }
            // Over the toolbar, as in Chrome, so the line runs unbroken along the notch.
            WorkspaceSplitPaneOutlineShape(toolbarSize: toolbarSize)
                .stroke(terminalPalette.splitPaneOutlineColor(isSelected: isSelected), lineWidth: WorkspaceSplitPaneMetrics.outlineWidth)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Fills a shown split's area in the terminals' background, the color the split's joined tabs run down into, as
/// Chrome's split tabs run into its toolbar; the panes and the resize area sit on it.
struct WorkspaceSplitAreaBackground: View {
    @Environment(\.tabBarTerminalPalette) private var terminalPalette

    var body: some View {
        Rectangle()
            .fill(terminalPalette.backgroundColor)
            .accessibilityHidden(true)
    }
}
