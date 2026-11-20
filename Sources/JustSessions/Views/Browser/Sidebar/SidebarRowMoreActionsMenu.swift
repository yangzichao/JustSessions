import SwiftUI

struct SidebarRowMoreActionsMenu<MenuItems: View>: View {
    let accessibilityLabel: LocalizedStringKey
    @ViewBuilder let menuItems: () -> MenuItems

    var body: some View {
        Menu {
            menuItems()
        } label: {
            SidebarRowMoreActionsLabel()
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More actions")
        .accessibilityLabel(accessibilityLabel)
    }
}

struct SidebarRowMoreActionsLabel: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .frame(
                width: InterfaceScale.points(SidebarRowMenuLabelMetrics.glyphSideBeforeInterfaceScale),
                height: InterfaceScale.points(SidebarRowMenuLabelMetrics.glyphSideBeforeInterfaceScale)
            )
            .contentShape(Rectangle())
    }
}
