import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation
    let title: String
    let onResume: () -> Void
    let onBranch: () -> Void
    let onRename: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: conversation.provider.symbolName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(conversation.provider == .claude ? .orange : .blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).lineLimit(1)
                Text(conversation.projectPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !conversation.isProjectAvailable {
                    Text("Project folder missing")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Spacer(minLength: 12)

            Text(conversation.updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 65, alignment: .trailing)

            Button("Resume", action: onResume)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!conversation.isProjectAvailable)
            Button("Branch", action: onBranch)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!conversation.isProjectAvailable)
                .help("Fork this conversation in the native CLI")
            Button(action: onRename) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Rename in Conversation Manager")
            .accessibilityLabel("Rename \(title)")
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}
