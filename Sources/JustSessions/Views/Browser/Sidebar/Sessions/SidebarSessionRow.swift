import SwiftUI

/// A session under its project: tool icon and title, then a pin and either its CLI's status or how long ago it was active.
struct SidebarSessionRow: View {
    /// What the row's trailing status follows.
    private enum StatusSource {
        /// A tab's CLI, running or ended.
        case tab(TerminalSession)
        /// A CLI running in tmux with no tab open.
        case detachedCLI(CLIActivity?)
    }

    @ObservedObject var store: ConversationStore
    let conversation: Conversation
    let sessionSelection: SessionMultiSelection
    let selectedConversations: [Conversation]
    let onClick: (Conversation) -> Void
    let onRename: (Conversation) -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void

    /// A tab whose CLI runs comes first, the selected one among them; then a CLI running in tmux with no tab; then a
    /// tab whose CLI ended or has not started. Nil when nothing runs the session.
    private func statusSource(tabs: [TerminalSession]) -> StatusSource? {
        let runningTabs = tabs.filter(\.isRunning)
        if let runningTab = runningTabs.first(where: { $0.id == store.selectedTerminalID }) ?? runningTabs.first {
            return .tab(runningTab)
        }
        if store.isRunningInTmux(conversation) { return .detachedCLI(store.detachedCLIActivities[conversation.id]) }
        return tabs.first.map { .tab($0) }
    }

    private func statusDescription(of source: StatusSource) -> String {
        switch source {
        case .tab(let tab):
            tab.runStatus.summary
        case .detachedCLI(let activity):
            SessionStatusIndicator.descriptionOfDetachedCLI(.running(activity), on: conversation.host)
        }
    }

    var body: some View {
        let title = store.title(for: conversation)
        let tabs = store.terminalSessions.filter { $0.conversation?.id == conversation.id }
        let statusSource = statusSource(tabs: tabs)
        let isHighlighted = sessionSelection.contains(conversation.id) || tabs.contains { $0.id == store.selectedTerminalID }
        let isInMultipleSelection = sessionSelection.hasMultipleSelected && sessionSelection.contains(conversation.id)
        let isPinned = store.pinnedItems.isPinned(conversationID: conversation.id)
        let statusDescription = statusSource.map(statusDescription(of:))

        Button {
            onClick(conversation)
        } label: {
            SidebarSessionRowLayout(provider: conversation.provider, isSelected: isHighlighted) {
                Text(title)
            } trailing: {
                if isPinned { PinnedIndicator() }
                statusIndicator(statusSource, description: statusDescription)
            }
        }
        .buttonStyle(.plain)
        .help("\(title) · \(conversation.provider.rawValue) · \(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))\(statusDescription.map { " · \($0)" } ?? "")")
        .accessibilityLabel("\(title), \(conversation.provider.rawValue)\(isPinned ? ", pinned" : "")\(statusDescription.map { ", \($0)" } ?? "")")
        .contextMenu {
            if isInMultipleSelection {
                SelectedSessionsContextMenu(
                    store: store,
                    selectedConversations: selectedConversations,
                    onDelete: { onRequestDeletion(.conversations(selectedConversations)) }
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
    private func statusIndicator(_ source: StatusSource?, description: String?) -> some View {
        switch source {
        case .tab(let tab):
            TerminalStatusIndicator(session: tab)
        case .detachedCLI(let activity):
            SessionStatusIndicator(status: .running(activity), description: description)
        case nil:
            SessionAgeLabel(lastActivity: conversation.updatedAt)
        }
    }
}
