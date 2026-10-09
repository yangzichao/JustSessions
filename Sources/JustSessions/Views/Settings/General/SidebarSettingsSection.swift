import SwiftUI

/// The sidebar part of the General tab: whether a session whose subagents ran sessions of their own offers a chevron
/// that lists them under it. Off by default, so the sidebar lists only the sessions you started.
struct SidebarSettingsSection: View {
    @AppStorage(SidebarSubagentRows.showsSubagentsUserDefaultsKey) private var showsSubagents = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sidebar")
                .font(.subheadline.weight(.medium))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Toggle("Show subagents under the sessions that started them", isOn: $showsSubagents)
                    .accessibilityIdentifier("settings.showsSubagents")
                HelpPopoverButton(
                    title: "Subagents",
                    explanation: "A session whose subagents ran sessions of their own gets a chevron before its icon. Click it to list them under the session and read them. Kiro's aren't listed; on SSH hosts, only Codex's and Antigravity's are."
                )
                .accessibilityIdentifier("settings.help.subagents")
            }
        }
    }
}
