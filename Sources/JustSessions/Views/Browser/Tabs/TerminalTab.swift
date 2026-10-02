import SwiftUI

struct TerminalTab: View {
    @ObservedObject var session: TerminalSession
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: (Conversation) -> Void
    let onClose: () -> Void

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
            .contextMenu {
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
}
