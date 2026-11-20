import SwiftUI

struct WorkspaceSplitPaneOverlay: View {
    let store: ConversationStore
    @ObservedObject var session: TerminalSession
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @Environment(\.tabBarTerminalPalette) private var terminalPalette
    @State private var miniToolbarSize: CGSize?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            WorkspaceSplitMiniToolbar(session: session, showsTabDetails: !isSelected, onSelect: onSelect, onClose: onClose)
                .onGeometryChange(for: CGSize.self, of: \.size) { miniToolbarSize = $0 }
                .splitPaneDragToRearrange(session.id, titled: session.displayTitle, in: store)
            WorkspaceSplitPaneOutlineShape(miniToolbarSize: miniToolbarSize)
                .stroke(terminalPalette.splitPaneOutlineColor(isSelected: isSelected), lineWidth: WorkspaceSplitPaneMetrics.outlineWidth)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

struct WorkspaceSplitAreaBackground: View {
    @Environment(\.tabBarTerminalPalette) private var terminalPalette

    var body: some View {
        Rectangle()
            .fill(terminalPalette.backgroundColor)
            .accessibilityHidden(true)
    }
}
