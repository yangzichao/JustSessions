import SwiftUI

struct HelpRemoteHostSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Set up an SSH host", systemImage: "network")
                .font(.headline)
            Text("**Install tmux on the host** so sessions survive a dropped connection or a closed tab. Built-in tmux is only for this Mac.")
            Text("Required: passwordless SSH, rsync, and the CLI. Antigravity and OpenCode also need python3; Antigravity needs lsof to delete sessions.")
                .foregroundStyle(ThemePalette.secondaryText)
            Text("Check `tmux -V` on the host, then choose **Add SSH host…** in the sidebar.")
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ThemePalette.raisedSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10).stroke(ThemePalette.hairline)
        }
        .accessibilityIdentifier("help.remote-hosts")
    }
}
