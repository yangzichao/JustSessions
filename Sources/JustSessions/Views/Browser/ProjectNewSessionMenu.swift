import SwiftUI

struct ProjectNewSessionMenu: View {
    let project: ProjectConversationGroup
    let showsTitle: Bool
    let onStart: (ConversationProvider) -> Void

    var body: some View {
        let isProjectAvailable = project.isProjectAvailable

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
        .help(helpText(isProjectAvailable: isProjectAvailable))
        .accessibilityLabel("New session in \(project.displayName)")
    }

    private func helpText(isProjectAvailable: Bool) -> String {
        if project.remoteLocation != nil { return "New sessions on remote hosts are not supported yet" }
        return isProjectAvailable
            ? "Start a new session in \(project.projectPath)"
            : "The project folder no longer exists"
    }
}
