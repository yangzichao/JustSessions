import SwiftUI

struct TerminalTab: View {
    @ObservedObject var session: TerminalSession
    let isSelected: Bool
    /// Whether this tab sits in a pane of its own.
    let isDocked: Bool
    /// False while this tab's own pane is the focused one, where a split would land.
    let canSplit: Bool
    let onSelect: () -> Void
    let onRename: (Conversation) -> Void
    /// Docks this tab beside (`false`) or below (`true`) the focused pane.
    let onSplit: (_ downward: Bool) -> Void
    /// Returns a docked tab to a plain tab; its pane closes.
    let onClosePane: () -> Void
    let onClose: () -> Void
    /// Reports drag positions in `WorkspacePaneDropZone.coordinateSpaceName`, for docking this tab into a pane.
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    TerminalStatusIndicator(session: session)
                    Text(session.displayTitle)
                        .lineLimit(1)
                        .frame(maxWidth: 180)
                }
            }
            .buttonStyle(WorkspaceTabButtonStyle(isSelected: isSelected))
            .help("Show \(session.displayTitle)")
            // Simultaneous, so a plain click still selects the tab; a real drag moves it into a pane.
            .simultaneousGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .named(WorkspacePaneDropZone.coordinateSpaceName))
                    .onChanged { onDragChanged($0.location) }
                    .onEnded { onDragEnded($0.location) }
            )
            .contextMenu {
                paneMenuItems
                if session.isPlainTerminal {
                    Button("Close terminal…", systemImage: "xmark", role: .destructive, action: onClose)
                } else {
                    Button("Rename", systemImage: "pencil") {
                        if let conversation = session.conversation { onRename(conversation) }
                    }
                    .disabled(session.conversation == nil)
                    if let conversation = session.conversation {
                        Divider()
                        ConversationSharingMenuItems(selections: [ConversationExportSelection(conversation: conversation, title: session.displayTitle)])
                        Divider()
                    }
                    Button("End session…", systemImage: "xmark", role: .destructive, action: onClose)
                }
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("End and close this terminal")
            .accessibilityLabel("Close \(session.displayTitle)")
        }
    }

    /// Splits act on the focused pane; a docked tab can also leave its pane.
    @ViewBuilder
    private var paneMenuItems: some View {
        Button("Split right", systemImage: "rectangle.split.2x1") { onSplit(false) }
            .disabled(!canSplit)
        Button("Split down", systemImage: "rectangle.split.1x2") { onSplit(true) }
            .disabled(!canSplit)
        if isDocked {
            Button("Close pane", systemImage: "rectangle", action: onClosePane)
        }
        Divider()
    }
}
