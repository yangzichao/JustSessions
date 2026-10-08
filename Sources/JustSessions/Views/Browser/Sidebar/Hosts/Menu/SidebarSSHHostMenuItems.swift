import SwiftUI

/// An SSH host's own settings: whether its tmux sessions use the host's tmux prefix, and removing the host. Its
/// heading's ⋯ shows only these, since the heading's + and refresh buttons already offer the rest of its right-click
/// menu, which ends with them.
struct SidebarSSHHostMenuItems: View {
    let actions: SidebarSSHHostActions

    var body: some View {
        Toggle(isOn: actions.usesTmuxPrefix) {
            Label("Use this host's tmux prefix", systemImage: "keyboard")
        }
        Divider()
        Button("Remove host", systemImage: "minus.circle", role: .destructive, action: actions.onRemove)
    }
}
