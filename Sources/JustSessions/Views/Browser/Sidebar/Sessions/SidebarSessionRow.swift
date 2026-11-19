import SwiftUI

/// A session under its project: tool icon and title, then a pin, an archive box, an hourglass for a session deleted
/// when its tab closes, and either its CLI's status or how long ago it was active.
/// The status gives way to a ⋯ while the pointer is over the row, which opens the same menu as a right-click.
struct SidebarSessionRow: View {
    let store: ConversationStore
    let conversation: Conversation
    let sessionSelection: SessionMultiSelection
    let selectedConversations: [Conversation]
    /// The sessions its subagents ran in; a chevron before its icon shows or hides them.
    let subagentCount: Int
    let isShowingSubagents: Bool
    /// While searching, the session's first match in its messages, shown under the title.
    var messageMatch: SessionMessageMatch? = nil
    /// While searching, the session's bookmarks whose label or tags hold the search text (SBF-05), shown first.
    var bookmarkMatches: [MessageBookmark] = []
    let onClick: (Conversation) -> Void
    let onToggleSubagents: () -> Void
    let onRename: (Conversation) -> Void
    let onRequestDeletion: (SessionDeletionRequest) -> Void

    @State private var isHovered = false
    /// Holds the pointer-over state for a test; nil follows `onHover` as in use.
    var isHoveredForTests: Bool? = nil
    private var hovered: Bool { isHoveredForTests ?? isHovered }

    private func statusDescription(of source: SessionRowStatusSource) -> String {
        switch source {
        case .tab(let tab):
            tab.runStatus.summary
        case .detachedCLI(let status):
            SessionStatusIndicator.descriptionOfDetachedCLI(status, on: conversation.host)
        }
    }

    var body: some View {
        let title = store.title(for: conversation)
        let tabs = store.terminalSessions.filter { $0.conversation?.id == conversation.id }
        let statusSource = store.sessionRowStatusSource(of: conversation)
        let isHighlighted = sessionSelection.contains(conversation.id) || tabs.contains { $0.id == store.selectedTerminalID }
        let isPinned = store.pinnedItems.isPinned(conversationID: conversation.id)
        let isArchived = store.archivedSessions.isArchived(conversationID: conversation.id)
        let isDeletedWhenTabCloses = store.sessionsDeletedWhenTabCloses.isDeletedWhenTabCloses(conversationID: conversation.id)
        let statusDescription = statusSource.map(statusDescription(of:))

        Button {
            onClick(conversation)
        } label: {
            SidebarSessionRowLayout(
                provider: conversation.provider,
                isSelected: isHighlighted,
                title: {
                    // Beside the title, as in the preview's header, so the pin isn't taken for one of the status icons.
                    HStack(spacing: 4) {
                        Text(title)
                        if isPinned { PinnedIndicator() }
                        if isArchived { ArchivedIndicator() }
                        if isDeletedWhenTabCloses { DeletedWhenTabClosesIndicator() }
                    }
                },
                detail: messageMatch == nil && bookmarkMatches.isEmpty
                    ? nil
                    : SidebarSessionMatchDetail(bookmarks: bookmarkMatches, messageMatch: messageMatch)
            ) {
                statusOrMoreActionsRoom(statusSource, description: statusDescription)
            }
        }
        .buttonStyle(ThemePlainButtonStyle(showsHover: false))
        .help(
            "\(title) · \(conversation.provider.rawValue) · \(SidebarSessionDateText.shared.text(for: conversation.updatedAt))\(statusDescription.map { " · \($0)" } ?? "")"
        )
        .accessibilityLabel(
            "\(title), \(conversation.provider.rawValue)\(isPinned ? ", pinned" : "")\(isArchived ? ", archived" : "")\(statusDescription.map { ", \($0)" } ?? "")"
        )
        .overlay(alignment: .leading) {
            if subagentCount > 0 {
                SubagentDisclosureButton(
                    isExpanded: isShowingSubagents,
                    subagentCount: subagentCount,
                    sessionTitle: title,
                    indentLevel: 0,
                    action: onToggleSubagents
                )
            }
        }
        .accessibilityValue(
            Text(
                verbatim: ([SidebarSessionBookmarkMatch.text(of: bookmarkMatches)] + [messageMatch?.snippet.text])
                    .compactMap { $0 }.joined(separator: ", "))
        )
        // Over the button rather than in it, so a click on the ⋯ opens its menu instead of selecting the session.
        .overlay(alignment: .trailing) {
            // In the view tree only while the pointer is over the row; see `SidebarProjectRow`.
            if hovered {
                SidebarRowMoreActionsMenu(accessibilityLabel: "More actions for \(title)") {
                    menuItems
                }
                .padding(.trailing, SidebarSessionRowMetrics.trailingPadding)
            }
        }
        .background(
            SidebarRowBackground(isSelected: isHighlighted, isHovered: hovered, selectionProvider: conversation.provider)
        )
        .onHover { isHovered = $0 }
        .contextMenu { menuItems }
    }

    /// The same items whether the menu comes from a right-click or the ⋯ button.
    @ViewBuilder
    private var menuItems: some View {
        if sessionSelection.hasMultipleSelected && sessionSelection.contains(conversation.id) {
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

    /// The status hides while the ⋯ is laid over its place. The row keeps the ⋯'s room either way, so the title doesn't
    /// move as the pointer passes over it.
    private func statusOrMoreActionsRoom(_ source: SessionRowStatusSource?, description: String?) -> some View {
        ZStack(alignment: .trailing) {
            statusIndicator(source, description: description)
                .opacity(hovered ? 0 : 1)
            SidebarRowMoreActionsLabel()
                .hidden()
        }
    }

    @ViewBuilder
    private func statusIndicator(_ source: SessionRowStatusSource?, description: String?) -> some View {
        switch source {
        case .tab(let tab):
            TerminalStatusIndicator(session: tab)
        case .detachedCLI(let status):
            SessionStatusIndicator(status: status, description: description)
        case nil:
            SessionAgeLabel(lastActivity: conversation.updatedAt)
        }
    }
}
