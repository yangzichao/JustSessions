import SwiftUI

struct ProjectNewSessionMenu: View {
    @Environment(\.locale) private var locale
    let location: ProjectLocation
    let projectDisplayName: String
    /// The tools installed on the project's host.
    let providers: [ConversationProvider]
    let showsTitle: Bool
    let onStart: (ConversationProvider) -> Void
    /// Adds a Terminal item, which opens a plain terminal in the project folder.
    var onOpenTerminal: (() -> Void)?

    var body: some View {
        Menu {
            if providers.isEmpty {
                Text(NewSessionProviderAvailability.noCLIFoundMessage(on: location.host, language: AppInterfaceLanguage(identifier: locale.identifier)))
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
        .disabled(!location.canStartSessions)
        .help(helpText)
        .accessibilityLabel("New session in \(projectDisplayName)")
    }

    private var helpText: LocalizedStringKey {
        guard location.canStartSessions else { return "The project folder no longer exists" }
        return location.host == .thisMac
            ? "Start a new session in \(location.path)"
            : "Start a new session in \(location.path) on \(location.host.displayName)"
    }
}
