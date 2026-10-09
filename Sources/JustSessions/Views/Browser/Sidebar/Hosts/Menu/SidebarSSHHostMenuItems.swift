import SwiftUI

/// An SSH host's own settings: whether its tmux sessions use the host's tmux prefix, its shell startup check, with what
/// it found when the startup gets in the way, and removing the host. Its heading's ⋯ shows only these, since the
/// heading's + and refresh buttons already offer the rest of its right-click menu, which ends with them.
struct SidebarSSHHostMenuItems: View {
    let actions: SidebarSSHHostActions

    var body: some View {
        Toggle(isOn: actions.usesTmuxPrefix) {
            Label("Use this host's tmux prefix", systemImage: "keyboard")
        }
        Divider()
        if let outcome = actions.shellStartupCheck?.outcome, outcome != .interactiveStartupWorks {
            // A menu shows text as an item that can't be chosen.
            if outcome == .usesLoginShellOnly {
                Text("CLIs start without your interactive shell startup")
            } else {
                Text("Your shell startup keeps CLIs from starting")
            }
            Button("Shell startup help", systemImage: "questionmark.circle") {
                NSWorkspace.shared.open(AppLinks.userGuideSSHShellStartupURL)
            }
        }
        // Also for a host whose startup was fine, after you change its startup files.
        Button(action: actions.onCheckShellStartup) {
            if actions.isCheckingShellStartup {
                Label("Checking shell startup…", systemImage: "arrow.clockwise")
            } else {
                Label("Check shell startup", systemImage: "arrow.clockwise")
            }
        }
        .disabled(actions.isCheckingShellStartup)
        Divider()
        Button("Remove host", systemImage: "minus.circle", role: .destructive, action: actions.onRemove)
    }
}
