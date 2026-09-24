import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation
    let title: String
    let isSelected: Bool
    let isPinned: Bool
    let onResume: () -> Void
    let onBranch: () -> Void
    let onRename: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let canDelete: Bool
    let isDeleting: Bool

    @State private var isHovered = false

    var body: some View {
        let projectAvailable = conversation.isProjectAvailable

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: conversation.provider.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(providerColor)
                    .frame(width: 30, height: 30)
                    .background(providerColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        if isPinned { PinnedIndicator(size: 9) }
                    }
                    HStack(spacing: 6) {
                        Text(conversation.provider.rawValue)
                        if !projectAvailable {
                            Text("·")
                            Text("Folder missing").foregroundStyle(.red)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                Text(conversation.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 60, alignment: .trailing)

                if isDeleting {
                    ProgressView().controlSize(.mini).frame(width: 24)
                } else {
                    Menu {
                        actionsMenuContent(projectAvailable: projectAvailable)
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 24, height: 24)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("More actions")
                    .accessibilityLabel("More actions for \(title)")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if projectAvailable { onResume() }
            }
            .help(projectAvailable ? "Double-click to resume" : "Project folder is missing")
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : isHovered ? Color.primary.opacity(0.045) : .clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .onHover { isHovered = $0 }

            Divider().padding(.leading, 52)
        }
        .contextMenu {
            actionsMenuContent(projectAvailable: projectAvailable)
        }
    }

    /// Shared by the row's right-click menu and its ⋯ menu.
    @ViewBuilder
    private func actionsMenuContent(projectAvailable: Bool) -> some View {
        Button(action: onResume) { Label("Resume", systemImage: "play") }
            .disabled(!projectAvailable)
        if conversation.provider.supportsBranchFromLauncher {
            Button(action: onBranch) { Label("Branch", systemImage: "arrow.triangle.branch") }
                .disabled(!projectAvailable)
        }
        Divider()
        Button(action: onRename) { Label("Rename", systemImage: "pencil") }
        Button(action: onTogglePin) {
            Label(isPinned ? "Unpin session" : "Pin session", systemImage: isPinned ? "pin.slash" : "pin")
        }
        if conversation.provider.supportsDeletionFromLauncher {
            Divider()
            Button(role: .destructive, action: onDelete) { Label("Delete session", systemImage: "trash") }
                .disabled(!canDelete)
        }
    }

    private var providerColor: Color {
        switch conversation.provider {
        case .claude: .orange
        case .codex: .blue
        case .antigravity: .purple
        }
    }
}
