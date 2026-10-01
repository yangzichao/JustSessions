import SwiftUI

/// The open tabs, grouped by project like tab groups in a browser: each project's tabs sit together behind a label
/// in the project's color, which collapses or expands the group.
struct WorkspaceTabBar: View {
    @ObservedObject var store: ConversationStore
    let onRenameConversation: (Conversation) -> Void
    @State private var closingSessionID: UUID?
    @State private var collapsedProjectKeys: Set<String> = []

    /// The host whose tmux can keep the closing tab's CLI running, when closing can leave it running.
    private var closingTabTmuxHost: SessionHost? {
        store.terminalSessions.first { $0.id == closingSessionID && $0.canKeepCLIRunningAfterClose }?.host
    }

    private var isClosingPlainTerminal: Bool {
        store.terminalSessions.first { $0.id == closingSessionID }?.isPlainTerminal == true
    }

    private var closingDialogTitle: String {
        if closingTabTmuxHost != nil { return "Close this tab?" }
        return isClosingPlainTerminal ? "Close this terminal?" : "End this CLI session?"
    }

    var body: some View {
        let groups = TerminalTabGroup.groups(of: store.terminalSessions, projectDirectoryKey: \.projectDirectoryKey)
        let colorsByProjectKey = TabGroupPalette.colorsByProjectKey(groups.map(\.projectDirectoryKey))
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(groups) { group in
                    TerminalTabGroupSection(
                        store: store,
                        group: group,
                        color: colorsByProjectKey[group.projectDirectoryKey] ?? .secondary,
                        isCollapsed: collapsedProjectKeys.contains(group.projectDirectoryKey),
                        onToggleCollapsed: { toggleCollapsed(group.projectDirectoryKey) },
                        onRenameConversation: onRenameConversation,
                        onCloseTab: { closingSessionID = $0 }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(ThemePalette.contentSurface)
        .onChange(of: groups.map(\.projectDirectoryKey)) { _, openProjectKeys in
            // A project whose last tab closed opens expanded next time.
            collapsedProjectKeys.formIntersection(openProjectKeys)
        }
        .confirmationDialog(
            closingDialogTitle,
            isPresented: Binding(isPresenting: $closingSessionID)
        ) {
            if closingTabTmuxHost != nil {
                Button("Keep running") {
                    if let closingSessionID { store.closeTerminal(closingSessionID, endingTmuxSession: false) }
                    closingSessionID = nil
                }
            }
            Button(isClosingPlainTerminal ? "Close terminal" : "End session", role: .destructive) {
                if let closingSessionID { store.closeTerminal(closingSessionID, endingTmuxSession: true) }
                closingSessionID = nil
            }
        } message: {
            if let closingTabTmuxHost {
                Text("Keep running leaves the CLI running in tmux on \(closingTabTmuxHost.nameInSentence); click the session to reattach. End session stops it.")
            } else if isClosingPlainTerminal {
                Text("The shell and anything still running in it will stop.")
            } else {
                Text("The terminal process will stop. Sessions saved by the CLI will appear in the project list after refresh.")
            }
        }
    }

    private func toggleCollapsed(_ projectKey: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            if collapsedProjectKeys.contains(projectKey) {
                collapsedProjectKeys.remove(projectKey)
            } else {
                collapsedProjectKeys.insert(projectKey)
            }
        }
    }
}
