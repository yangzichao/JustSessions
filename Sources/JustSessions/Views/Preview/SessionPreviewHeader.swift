import SwiftUI

struct SessionPreviewHeader: View {
    @ObservedObject var store: ConversationStore
    let conversation: Conversation
    let onRename: () -> Void
    let onDelete: () -> Void
    let onRead: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                sessionTitle
                Spacer(minLength: 8)
                sessionActions
            }
            VStack(alignment: .leading, spacing: 12) {
                sessionTitle
                HStack {
                    Spacer(minLength: 0)
                    sessionActions
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var sessionTitle: some View {
        let title = store.title(for: conversation)
        let isPinned = store.pinnedItems.isPinned(conversationID: conversation.id)

        return HStack(alignment: .center, spacing: 12) {
            conversation.provider.iconImage(size: 15)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(conversation.provider.tintColor)
                .frame(width: 34, height: 34)
                .background(conversation.provider.tintColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

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
                    // With SSH hosts added, every session names its host, this Mac included.
                    if store.hasRemoteHosts {
                        Label(conversation.host.displayName, systemImage: conversation.host.symbolName)
                        Text("·")
                    }
                    Text(store.projectDisplayName(forProjectPath: conversation.projectDirectoryKey))
                        .help(conversation.projectLocation.copyablePath)
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

        }
        .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
    }

    private var sessionActions: some View {
        HStack(spacing: 10) {
            if conversation.provider == .claude || conversation.provider == .codex || conversation.provider == .kiro || conversation.provider == .antigravity {
                Button("Read", systemImage: "book", action: onRead)
                    .buttonStyle(QuietBorderedButtonStyle())
                    .help("Open in a separate reading window")
                    .accessibilityIdentifier("preview.open-reading-window")
            }
            Button("Resume", systemImage: "play.fill") { store.launch(conversation, action: .resume) }
                .buttonStyle(ProviderProminentButtonStyle(tint: conversation.provider.emphasisTintColor))
                .disabled(!store.canLaunch(conversation, action: .resume))
            if conversation.provider.supportsBranchFromLauncher {
                Button("Branch", systemImage: "arrow.triangle.branch") { store.launch(conversation, action: .branch) }
                    .buttonStyle(QuietBorderedButtonStyle())
                    .disabled(!store.canLaunch(conversation, action: .branch))
                    .help("Fork in the native CLI")
            }
            moreActionsMenu
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var moreActionsMenu: some View {
        Menu {
            SessionManagementMenuItems(store: store, conversation: conversation, onRename: onRename, onDelete: onDelete)
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
