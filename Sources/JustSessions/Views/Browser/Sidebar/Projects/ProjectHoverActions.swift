import SwiftUI

/// A project's ⋯ menu and + new session menu, which show while the pointer is over its row in Projects or its group's
/// heading in Open tabs.
struct ProjectHoverActions<MenuItems: View>: View {
    @ObservedObject var store: ConversationStore
    let location: ProjectLocation
    let projectDisplayName: String
    let onNewSession: (ConversationProvider) -> Void
    @ViewBuilder let menuItems: () -> MenuItems

    var body: some View {
        HStack(spacing: 0) {
            SidebarRowMoreActionsMenu(accessibilityLabel: "More actions for \(projectDisplayName)", menuItems: menuItems)
            ProjectNewSessionMenu(
                location: location,
                projectDisplayName: projectDisplayName,
                providers: store.newSessionProviders(on: location.host),
                showsTitle: false,
                onStart: onNewSession,
                onOpenTerminal: { store.openPlainTerminal(in: location) }
            )
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
