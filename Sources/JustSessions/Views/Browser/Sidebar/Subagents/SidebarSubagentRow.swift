import SwiftUI

struct SidebarSubagentRow: View {
    let store: ConversationStore
    let row: SidebarSubagentRows.Row
    let isSelected: Bool
    let isExpanded: Bool
    let onClick: (Conversation) -> Void
    let onToggleSubagents: () -> Void

    @State private var isHovered = false
    var isHoveredForTests: Bool? = nil
    private var hovered: Bool { isHoveredForTests ?? isHovered }

    var body: some View {
        let conversation = row.conversation
        let title = store.title(for: conversation)

        Button {
            onClick(conversation)
        } label: {
            SidebarSessionRowLayout(provider: conversation.provider, isSelected: isSelected, indentLevel: row.depth) {
                Text(title)
            } trailing: {
                ZStack(alignment: .trailing) {
                    HStack(spacing: 6) {
                        if let model = conversation.model {
                            Text(verbatim: model.shortName)
                                .font(ThemeFont.detail)
                                .foregroundStyle(ThemePalette.tertiaryText)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        SessionAgeLabel(lastActivity: conversation.updatedAt)
                    }
                    .opacity(hovered ? 0 : 1)
                    SidebarRowMoreActionsLabel()
                        .hidden()
                }
            }
        }
        .buttonStyle(ThemePlainButtonStyle(showsHover: false))
        .help(helpText(title: title, conversation: conversation))
        .accessibilityLabel(accessibilityText(title: title, conversation: conversation))
        .overlay(alignment: .leading) {
            if row.subagentCount > 0 {
                SubagentDisclosureButton(
                    isExpanded: isExpanded,
                    subagentCount: row.subagentCount,
                    sessionTitle: title,
                    indentLevel: row.depth,
                    action: onToggleSubagents
                )
            }
        }
        .overlay(alignment: .trailing) {
            if hovered {
                SidebarRowMoreActionsMenu(accessibilityLabel: "More actions for \(title)") {
                    menuItems
                }
                .padding(.trailing, SidebarSessionRowMetrics.trailingPadding)
            }
        }
        .background(
            SidebarRowBackground(isSelected: isSelected, isHovered: hovered, selectionProvider: conversation.provider)
        )
        .onHover { isHovered = $0 }
        .contextMenu { menuItems }
    }

    private func helpText(title: String, conversation: Conversation) -> LocalizedStringKey {
        let date = SidebarSessionDateText.shared.text(for: conversation.updatedAt)
        guard let model = conversation.model else { return "\(title) · \(conversation.provider.rawValue) subagent · \(date)" }
        return "\(title) · \(conversation.provider.rawValue) subagent · \(model.label) · \(date)"
    }

    private func accessibilityText(title: String, conversation: Conversation) -> LocalizedStringKey {
        guard let model = conversation.model else { return "\(title), \(conversation.provider.rawValue) subagent" }
        return "\(title), \(conversation.provider.rawValue) subagent, \(model.label)"
    }

    private var menuItems: some View {
        SessionManagementMenuItems(store: store, conversation: row.conversation, onRename: {}, onDelete: {})
    }
}
