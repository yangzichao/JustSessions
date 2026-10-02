import SwiftUI

struct ProjectNewSessionMenu: View {
    @Environment(\.locale) private var locale
    let project: ProjectConversationGroup
    /// The tools installed on the project's host.
    let providers: [ConversationProvider]
    let showsTitle: Bool
    let onStart: (ConversationProvider) -> Void
    /// Adds a Terminal item, which opens a plain terminal in the project folder.
    var onOpenTerminal: (() -> Void)?

    var body: some View {
        let canStartNewSession = project.canStartNewSession

        Menu {
            if providers.isEmpty {
                Text(NewSessionProviderAvailability.noCLIFoundMessage(on: project.host, language: AppInterfaceLanguage(identifier: locale.identifier)))
            }
            ForEach(providers) { provider in
                Button {
                    onStart(provider)
                } label: {
                    Label {
                        Text(provider.rawValue)
                    } icon: {
                        provider.iconImage()
                    }
                }
            }
            if let onOpenTerminal {
                Divider()
                Button("Terminal", systemImage: "apple.terminal", action: onOpenTerminal)
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

    private var helpText: LocalizedStringKey {
        guard project.canStartNewSession else { return "The project folder no longer exists" }
        return project.host == .thisMac
            ? "Start a new session in \(project.location.path)"
            : "Start a new session in \(project.location.path) on \(project.host.displayName)"
    }
}
