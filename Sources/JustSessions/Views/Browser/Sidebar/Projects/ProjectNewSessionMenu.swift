import SwiftUI

struct ProjectNewSessionMenu: View {
    let location: ProjectLocation
    let projectDisplayName: String
    let providers: [ConversationProvider]
    let showsTitle: Bool
    let onStart: (ConversationProvider) -> Void
    var onOpenTerminal: (() -> Void)?

    var body: some View {
        Menu {
            NewSessionProviderMenuItems(providers: providers, host: location.host, onStart: onStart)
            if let onOpenTerminal {
                Divider()
                Button("Terminal", systemImage: "apple.terminal", action: onOpenTerminal)
            }
        } label: {
            if showsTitle {
                Label("New session", systemImage: "plus")
            } else {
                Image(systemName: "plus")
                    .frame(
                        width: InterfaceScale.points(SidebarRowMenuLabelMetrics.glyphSideBeforeInterfaceScale),
                        height: InterfaceScale.points(SidebarRowMenuLabelMetrics.glyphSideBeforeInterfaceScale)
                    )
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
