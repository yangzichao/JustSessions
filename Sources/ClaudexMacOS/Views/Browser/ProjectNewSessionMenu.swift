import SwiftUI

struct ProjectNewSessionMenu: View {
    let project: ProjectConversationGroup
    let showsTitle: Bool
    let onStart: (ConversationProvider) -> Void

    private var isProjectAvailable: Bool {
        project.conversations.first?.isProjectAvailable == true
    }

    var body: some View {
        Menu {
            Button("Claude Code", systemImage: ConversationProvider.claude.symbolName) {
                onStart(.claude)
            }
            Button("Codex", systemImage: ConversationProvider.codex.symbolName) {
                onStart(.codex)
            }
        } label: {
            if showsTitle {
                Label("New session", systemImage: "plus")
            } else {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
        }
        .disabled(!isProjectAvailable)
        .help(isProjectAvailable
            ? "Start a new session in \(project.projectPath)"
            : "The project folder no longer exists")
        .accessibilityLabel("New session in \(project.projectName)")
    }
}
