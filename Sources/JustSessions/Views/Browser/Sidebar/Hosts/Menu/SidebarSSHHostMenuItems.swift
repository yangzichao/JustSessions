import SwiftUI

/// An SSH host's own settings: whether its tmux sessions use the host's tmux prefix, what its shell startup check
/// found when the startup gets in the way, and removing the host. Its heading's ⋯ shows only these, since the
/// heading's + and refresh buttons already offer the rest of its right-click menu, which ends with them.
struct SidebarSSHHostMenuItems: View {
    let actions: SidebarSSHHostActions

    var body: some View {
        Toggle(isOn: actions.usesTmuxPrefix) {
            Label("Use this host's tmux prefix", systemImage: "keyboard")
        }
        if let outcome = actions.shellStartupCheck?.outcome, outcome != .interactiveStartupWorks {
            Divider()
            // A menu shows text as an item that can't be chosen.
            if outcome == .usesLoginShellOnly {
                Text("CLIs start without your interactive shell startup")
            } else {
                Text("Your shell startup keeps CLIs from starting")
            }
            Button("Shell startup help", systemImage: "questionmark.circle") {
                NSWorkspace.shared.open(AppLinks.userGuideSSHShellStartupURL)
            }
            Button(action: actions.onCheckShellStartupAgain) {
                if actions.isCheckingShellStartup {
                    Label("Checking shell startup…", systemImage: "arrow.clockwise")
                } else {
                    Label("Check shell startup again", systemImage: "arrow.clockwise")
                }
            }
            .disabled(actions.isCheckingShellStartup)
        }
        Divider()
        Button("Remove host", systemImage: "minus.circle", role: .destructive, action: actions.onRemove)
    }
}
