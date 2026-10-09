import SwiftUI

/// An SSH host's own settings: whether its tmux sessions use the host's tmux prefix, its shell startup check with what
/// it last found, and removing the host. Its heading's ⋯ shows only these, since the heading's + and refresh buttons
/// already offer the rest of its right-click menu, which ends with them.
struct SidebarSSHHostMenuItems: View {
    let actions: SidebarSSHHostActions

    var body: some View {
        Toggle(isOn: actions.usesTmuxPrefix) {
            Label("Use this host's tmux prefix", systemImage: "keyboard")
        }
        Divider()
        // A menu shows text as an item that can't be chosen.
        switch actions.shellStartupCheck?.outcome {
        case nil:
            EmptyView()
        case .interactiveStartupWorks:
            Text("Shell startup is fine")
        case .usesLoginShellOnly:
            Text("CLIs skip your interactive shell startup, which starts another program")
            shellStartupHelpButton
        case .blocked:
            Text("Your shell startup keeps CLIs from starting!")
            shellStartupHelpButton
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

    private var shellStartupHelpButton: some View {
        Button("Shell startup help", systemImage: "questionmark.circle") {
            NSWorkspace.shared.open(AppLinks.userGuideSSHShellStartupURL)
        }
    }
}
