import SwiftUI

struct HelpRemoteHostSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("SSH hosts", systemImage: "network")
                .font(.headline)
            Text("Choose **Add SSH host…** in the sidebar. The host needs passwordless SSH, rsync, and the CLI.")
            Text("Install tmux there too, or a dropped connection stops the CLI. Antigravity and OpenCode also need python3.")
                .foregroundStyle(ThemePalette.secondaryText)
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
