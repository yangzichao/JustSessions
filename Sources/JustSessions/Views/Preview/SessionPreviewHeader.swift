import SwiftUI

struct SessionPreviewHeader: View {
    @ObservedObject var store: ConversationStore
    let conversation: Conversation
    let onRename: () -> Void
    let onDelete: () -> Void
    /// The project folder last found gone: checked when the session shows and whenever the app comes back to the
    /// front, so a folder moved back in Finder turns Resume on again without picking the session again.
    @State private var missingProjectFolder: ProjectLocation?

    private var isProjectFolderMissing: Bool {
        missingProjectFolder == conversation.projectLocation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            if isProjectFolderMissing {
                MissingProjectFolderNote(projectPath: conversation.projectPath)
            }
            if store.runningTerminal(for: conversation) == nil,
               let otherWindowTab = store.runningTerminalInAnotherWindow(for: conversation) {
                SessionInAnotherWindowNote(tab: otherWindowTab) {
                    store.showRunningTerminalInAnotherWindow(for: conversation)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .onChange(of: conversation.projectLocation, initial: true) { checkProjectFolder() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkProjectFolder()
        }
    }

    private func checkProjectFolder() {
        missingProjectFolder = conversation.isProjectAvailable ? nil : conversation.projectLocation
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
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

        }
        .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
    }

    /// A subagent's session names the session that started it instead, since it is only read.
    private var sessionActions: some View {
        HStack(spacing: 10) {
            if conversation.isSubagent {
                subagentLabel
            } else {
                launchActions
            }
            moreActionsMenu
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var subagentLabel: some View {
        let parent = conversation.parentID.flatMap(store.conversation(withID:))
        return Label {
            if let parent {
                Text("Subagent of \(store.title(for: parent))")
            } else {
                Text("Subagent")
            }
        } icon: {
            Image(systemName: "arrow.turn.down.right")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(maxWidth: 260, alignment: .trailing)
        .help("A subagent ran this session for the session that started it. It can be read here, but not resumed or deleted on its own.")
    }

    @ViewBuilder
    private var launchActions: some View {
        Button("Resume", systemImage: "play.fill") { store.launch(conversation, action: .resume) }
            .buttonStyle(ProviderProminentButtonStyle(tint: conversation.provider.emphasisTintColor))
            .disabled(!store.canLaunch(conversation, action: .resume))
            .onboardingTourStop(.resume)
        if conversation.provider.supportsBranchFromLauncher {
            Button("Branch", systemImage: "arrow.triangle.branch") { store.launch(conversation, action: .branch) }
                .buttonStyle(QuietBorderedButtonStyle())
                .disabled(!store.canLaunch(conversation, action: .branch))
                .help("Fork in the native CLI")
        }
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
