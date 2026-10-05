import SwiftUI

/// SSH setup guidance in the Help & feedback page: adding a host, and what it needs.
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
            Link("SSH setup in the user guide ↗", destination: AppLinks.userGuideSSHHostsURL)
                .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
        }
        .accessibilityIdentifier("help.remote-hosts")
    }
}
