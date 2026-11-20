import SwiftUI

struct ProjectHoverActions<MenuItems: View>: View {
    let store: ConversationStore
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

    private static var hoverMenuCount: CGFloat { 2 }

    static var placeholder: some View {
        Color.clear
            .frame(
                width: InterfaceScale.points(hoverMenuCount * SidebarRowMenuLabelMetrics.glyphSideBeforeInterfaceScale),
                height: InterfaceScale.points(SidebarRowMenuLabelMetrics.fixedSizeBorderlessMenuHeightBeforeInterfaceScale)
            )
    }
}
