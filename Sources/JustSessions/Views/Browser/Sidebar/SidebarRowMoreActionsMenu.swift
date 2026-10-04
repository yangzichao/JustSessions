import SwiftUI

/// The ⋯ a project or session row shows while the pointer is over it. It opens the row's right-click menu, so the menu
/// can be found without a right-click.
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

/// The ⋯ glyph. A row can also lay it out hidden, to keep the ⋯'s room while the pointer is elsewhere.
struct SidebarRowMoreActionsLabel: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
    }
}
