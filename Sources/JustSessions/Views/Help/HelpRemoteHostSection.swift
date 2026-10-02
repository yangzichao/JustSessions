import SwiftUI

struct HelpRemoteHostSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Remote hosts over SSH", systemImage: "network")
                .font(.headline)
            Text("**Install tmux on the remote host.** The app's bundled tmux is only for this Mac. Remote sessions need their own tmux to keep running after a disconnect or closing a tab.")
            Text("The host also needs passwordless SSH, rsync, and your coding CLI. Antigravity also needs python3; deleting its sessions needs lsof.")
                .foregroundStyle(ThemePalette.secondaryText)
            Text("Run `tmux -V` on the host to check installation. Then choose **Add SSH host…** and enter an SSH config alias or `user@hostname`.")
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
