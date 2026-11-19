import SwiftUI

struct HelpTroubleshootingSection: View {
    var body: some View {
        HelpSection(title: "If a session is missing") {
            HelpBulletList(items: [
                "In **Projects**, clear the filters, then click the host's refresh button.",
                "Check that the CLI runs in your usual terminal and has saved a conversation. **New session** offers only the CLIs it finds installed.",
                "On an SSH host, check that SSH works, or click **Connect…** on its heading, then check rsync and the CLI there. A host at a local address also needs **Local Network** in Permissions.",
            ])
            Link("More in the user guide ↗", destination: AppLinks.userGuideTroubleshootingURL)
                .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
        }
        .accessibilityIdentifier("help.troubleshooting")
    }
}
