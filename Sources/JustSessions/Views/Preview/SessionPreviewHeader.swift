import SwiftUI

struct SessionPreviewHeader: View {
    @ObservedObject var store: ConversationStore
    let conversation: Conversation
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let title = store.title(for: conversation)
        let isPinned = store.pinnedItems.isPinned(conversationID: conversation.id)

        HStack(alignment: .center, spacing: 12) {
            Image(systemName: conversation.provider.symbolName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(conversation.provider.tintColor)
                .frame(width: 34, height: 34)
                .background(conversation.provider.tintColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isPinned { PinnedIndicator(size: 10) }
                }
                HStack(spacing: 5) {
                    Text(conversation.provider.rawValue)
                    Text("·")
                    if let remoteHost = conversation.remoteHost {
                        Label(remoteHost, systemImage: "network")
                        Text("·")
                    }
                    Text(store.projectDisplayName(forProjectPath: conversation.projectDirectoryKey))
                        .help(RemoteProjectKey.copyablePath(ofKey: conversation.projectDirectoryKey))
                    Text("·")
                    Text(conversation.updatedAt, style: .relative)
                    if !conversation.isProjectAvailable {
                        Text("·")
                        Text("Folder missing").foregroundStyle(.red)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button("Resume") { store.launch(conversation, action: .resume) }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canLaunch(conversation, action: .resume))
            if conversation.provider.supportsBranchFromLauncher {
                Button("Branch") { store.launch(conversation, action: .branch) }
                    .buttonStyle(.bordered)
                    .disabled(!store.canLaunch(conversation, action: .branch))
                    .help("Fork in the native CLI")
            }
            moreActionsMenu(isPinned: isPinned)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    private func moreActionsMenu(isPinned: Bool) -> some View {
        Menu {
            Button("Rename", systemImage: "pencil", action: onRename)
            Button(isPinned ? "Unpin session" : "Pin session", systemImage: isPinned ? "pin.slash" : "pin") {
                store.setPinned(!isPinned, conversation: conversation)
            }
            Button("Copy session ID", systemImage: "doc.on.doc") {
                SessionLocationActions.copySessionID(conversation)
            }
            if !conversation.isRemote {
                Button("Reveal session file in Finder", systemImage: "doc.text.magnifyingglass") {
                    SessionLocationActions.revealSessionFile(conversation)
                }
            }
            if conversation.supportsDeletionFromLauncher {
                Divider()
                Button("Delete session…", systemImage: "trash", role: .destructive, action: onDelete)
                    .disabled(store.hasTerminal(for: conversation) || store.isLoading || store.isDeletingSessions)
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More actions")
        .accessibilityLabel("More actions for \(store.title(for: conversation))")
    }
}
