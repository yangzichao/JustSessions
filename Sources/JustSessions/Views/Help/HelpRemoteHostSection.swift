import SwiftUI

struct HelpRemoteHostSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Remote hosts over SSH", systemImage: "network")
                .font(.headline)
            Text("**Install tmux on each remote host.** The Mac's bundled tmux only works locally.")
            Text("Also required: passwordless SSH, rsync, and your CLI. Antigravity needs python3; lsof for deletion.")
                .foregroundStyle(ThemePalette.secondaryText)
            Text("Check `tmux -V` on the host, then **Add SSH host…** with an alias or `user@hostname`.")
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
