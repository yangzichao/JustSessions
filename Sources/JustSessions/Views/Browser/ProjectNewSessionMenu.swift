import SwiftUI

struct ProjectNewSessionMenu: View {
    let project: ProjectConversationGroup
    let showsTitle: Bool
    let onStart: (ConversationProvider) -> Void

    var body: some View {
        let isProjectAvailable = project.conversations.first?.isProjectAvailable == true

        Menu {
            ForEach(ConversationProvider.allCases) { provider in
                Button(provider.rawValue, systemImage: provider.symbolName) {
                    onStart(provider)
                }
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
        .accessibilityLabel("New session in \(project.displayName)")
    }
}
