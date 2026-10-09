import SwiftUI

/// SSH setup guidance in the Help page: adding a host, and what it needs.
struct HelpRemoteHostSection: View {
    var body: some View {
        HelpSection(title: "SSH hosts") {
            Text("Choose **Add SSH host…** at the bottom of the sidebar, then enter `user@hostname` or an alias from `~/.ssh/config`. Your code and CLIs run on the host; its history is cached on this Mac.")
            Text("The host needs:")
            HelpBulletList(items: [
                "Passwordless SSH from this Mac",
                "`rsync`, and the CLIs you use",
                "`tmux`, so a CLI keeps running when the connection drops",
                "`python3`, for Antigravity and OpenCode",
            ])
            Text("The tmux sessions the app starts on a host have no prefix key, so every key reaches the CLI. To use your own tmux prefix there, point at the host's heading, click its **⋯**, and choose **Use this host's tmux prefix**.")
            Link("SSH setup in the user guide ↗", destination: AppLinks.userGuideSSHHostsURL)
                .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
            Text("If a session opens a shell instead of its CLI, the host's shell startup starts another program first, such as tmux or zsh. The app checks for this and works around it when it can; the host's **⋯** says what it found.")
            Link("Shell startup in the user guide ↗", destination: AppLinks.userGuideSSHShellStartupURL)
                .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
        }
        .accessibilityIdentifier("help.remote-hosts")
    }
}
