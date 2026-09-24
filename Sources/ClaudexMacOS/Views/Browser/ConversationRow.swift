import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation
    let title: String
    let isSelected: Bool
    let onResume: () -> Void
    let onBranch: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let canDelete: Bool
    let isDeleting: Bool

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: conversation.provider.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(providerColor)
                    .frame(width: 30, height: 30)
                    .background(providerColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(conversation.provider.rawValue)
                        if !conversation.isProjectAvailable {
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

                Button("Resume", action: onResume)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!conversation.isProjectAvailable)
                Button("Branch", action: onBranch)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(!conversation.isProjectAvailable)
                    .help("Fork in the native CLI")

                if isDeleting {
                    ProgressView().controlSize(.mini).frame(width: 24)
                } else {
                    Menu {
                        Button(action: onRename) { Label("Rename", systemImage: "pencil") }
                        Divider()
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete session", systemImage: "trash")
                        }
                        .disabled(!canDelete)
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
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : isHovered ? Color.primary.opacity(0.045) : .clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .onHover { isHovered = $0 }

            Divider().padding(.leading, 52)
        }
        .contextMenu {
            Button("Resume", action: onResume).disabled(!conversation.isProjectAvailable)
            Button("Branch", action: onBranch).disabled(!conversation.isProjectAvailable)
            Button("Rename", action: onRename)
            Divider()
            Button("Delete session", role: .destructive, action: onDelete).disabled(!canDelete)
        }
    }

    private var providerColor: Color {
        conversation.provider == .claude ? .orange : .blue
    }
}
