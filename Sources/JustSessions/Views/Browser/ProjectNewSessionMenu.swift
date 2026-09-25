import SwiftUI

struct ProjectNewSessionMenu: View {
    let project: ProjectConversationGroup
    let showsTitle: Bool
    let onStart: (ConversationProvider) -> Void

    var body: some View {
        let canStartNewSession = project.canStartNewSession

        Menu {
            ForEach(project.newSessionProviders) { provider in
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
        .disabled(!canStartNewSession)
        .help(helpText)
        .accessibilityLabel("New session in \(project.displayName)")
    }

    private var helpText: String {
        if let remoteLocation = project.remoteLocation {
            return "Start a new session in \(remoteLocation.projectPath) on \(remoteLocation.host)"
        }
        return project.isProjectAvailable
            ? "Start a new session in \(project.projectPath)"
            : "The project folder no longer exists"
    }
}
