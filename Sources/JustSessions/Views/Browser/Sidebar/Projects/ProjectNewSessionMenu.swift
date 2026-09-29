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
        guard project.canStartNewSession else { return "The project folder no longer exists" }
        return project.host == .thisMac
            ? "Start a new session in \(project.location.path)"
            : "Start a new session in \(project.location.path) on \(project.host.displayName)"
    }
}
