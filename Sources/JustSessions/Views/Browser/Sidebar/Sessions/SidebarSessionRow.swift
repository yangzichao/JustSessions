import SwiftUI

/// A session under its project: tool icon and title, then a pin and either its terminal's status or how long ago it was active.
struct SidebarSessionRow: View {
    @ObservedObject var store: ConversationStore
    let conversation: Conversation
    let sessionSelection: SessionMultiSelection
    let selectedConversations: [Conversation]
    let onClick: (Conversation) -> Void
    let onRename: (Conversation) -> Void
    let onClearSelection: () -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void

    /// The selected tab when it shows this session, otherwise any tab that does.
    private var openTerminal: TerminalSession? {
        store.terminalSessions.first { $0.conversation?.id == conversation.id && $0.id == store.selectedTerminalID }
            ?? store.terminalSessions.first { $0.conversation?.id == conversation.id }
    }

    var body: some View {
        let title = store.title(for: conversation)
        let openTerminal = openTerminal
        let isHighlighted = sessionSelection.contains(conversation.id)
            || (openTerminal != nil && openTerminal?.id == store.selectedTerminalID)
        let isInMultipleSelection = sessionSelection.hasMultipleSelected && sessionSelection.contains(conversation.id)
        let isPinned = store.pinnedItems.isPinned(conversationID: conversation.id)

        Button {
            onClick(conversation)
        } label: {
            SidebarSessionRowLayout(provider: conversation.provider, isSelected: isHighlighted) {
                Text(title)
            } trailing: {
                if isPinned { PinnedIndicator() }
                activityIndicator(openTerminal: openTerminal)
            }
        }
        .buttonStyle(.plain)
        .help("\(title) · \(conversation.provider.rawValue) · \(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))")
        .accessibilityLabel("\(title), \(conversation.provider.rawValue)\(isPinned ? ", pinned" : "")\(openTerminal == nil ? "" : ", open terminal")")
        .contextMenu {
            if isInMultipleSelection {
                SelectedSessionsContextMenu(
                    store: store,
                    selectedConversations: selectedConversations,
                    onDelete: { onRequestDeletion(.conversations(selectedConversations)) },
                    onClear: onClearSelection
                )
            } else {
                SingleSessionContextMenu(
                    store: store,
                    conversation: conversation,
                    onRename: { onRename(conversation) },
                    onDelete: { onRequestDeletion(.conversation(conversation)) }
                )
            }
        }
    }

    @ViewBuilder
    private func activityIndicator(openTerminal: TerminalSession?) -> some View {
        if let openTerminal {
            TerminalStatusIndicator(session: openTerminal)
        } else if store.isRunningInTmux(conversation) {
            TmuxRunningIndicator(host: conversation.host)
        } else {
            SessionAgeLabel(lastActivity: conversation.updatedAt)
        }
    }
}
