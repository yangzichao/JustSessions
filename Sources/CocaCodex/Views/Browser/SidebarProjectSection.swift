import SwiftUI

struct SidebarProjectSection: View {
    @ObservedObject var store: ConversationStore
    let project: ProjectConversationGroup
    let parentLabel: String?
    let isExpanded: Bool
    let isSelected: Bool
    let selectedConversationID: String?
    let onToggle: () -> Void
    let onNewSession: (ConversationProvider) -> Void
    let onSelectConversation: (Conversation) -> Void

    private var openTerminalCount: Int {
        store.terminalSessions.filter { $0.projectDirectoryKey == project.id }.count
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                Button(action: onToggle) {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 10)
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .frame(width: 15)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(project.projectName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if let parentLabel {
                                Text(parentLabel)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 3)
                        if openTerminalCount > 0 {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(Color.accentColor)
                        }
                        Text("\(project.conversations.count)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .padding(.horizontal, 10)
                    .frame(height: parentLabel == nil ? 32 : 42)
                    .contentShape(Rectangle())
                    .background(isSelected ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .help(project.projectPath)
                .accessibilityLabel("\(project.projectName), \(project.conversations.count) \(project.conversations.count == 1 ? "session" : "sessions"), \(openTerminalCount) open")

                ProjectNewSessionMenu(project: project, showsTitle: false, onStart: onNewSession)
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    .padding(.trailing, 4)
            }

            if isExpanded {
                ForEach(project.conversations) { conversation in
                    sessionRow(conversation)
                }
            }
        }
    }

    private func sessionRow(_ conversation: Conversation) -> some View {
        let openTerminal = store.terminalSessions.first {
            $0.conversation?.id == conversation.id && $0.action == .resume && $0.id == store.selectedTerminalID
        } ?? store.terminalSessions.first {
            $0.conversation?.id == conversation.id && $0.action == .resume
        }
        let isHighlighted = selectedConversationID == conversation.id
            || (openTerminal != nil && openTerminal?.id == store.selectedTerminalID)

        return Button {
            onSelectConversation(conversation)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: conversation.provider.symbolName)
                    .font(.system(size: 11))
                    .foregroundStyle(providerColor(for: conversation.provider))
                    .frame(width: 14)
                Text(store.title(for: conversation))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 3)
                if let openTerminal {
                    TerminalStatusIndicator(session: openTerminal)
                }
            }
            .font(.system(size: 11, weight: isHighlighted ? .medium : .regular))
            .foregroundStyle(isHighlighted ? .primary : .secondary)
            .padding(.leading, 32)
            .padding(.trailing, 10)
            .frame(height: 28)
            .contentShape(Rectangle())
            .background(isHighlighted ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help("\(store.title(for: conversation)) · \(conversation.provider.rawValue)")
        .accessibilityLabel("\(store.title(for: conversation)), \(conversation.provider.rawValue)\(openTerminal == nil ? "" : ", open terminal")")
    }

    private func providerColor(for provider: ConversationProvider) -> Color {
        switch provider {
        case .claude: .orange
        case .codex: .blue
        case .antigravity: .purple
        }
    }
}
