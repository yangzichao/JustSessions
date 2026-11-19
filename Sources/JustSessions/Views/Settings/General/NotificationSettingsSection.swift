import SwiftUI

struct NotificationSettingsSection: View {
    @ObservedObject var settingsStore: SessionNotificationSettingsStore
    @State private var isTurnedOffInSystemSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Notify me when a session")
                    .font(ThemeFont.heading)
                HelpPopoverButton(
                    title: "Notifications",
                    explanation:
                        "Supports Claude Code, Codex, Antigravity, Pi, OpenCode, and Kiro CLI, on this Mac or an SSH host, including sessions running in tmux without an open tab. Sessions you are viewing do not notify you. Click a notification to open its session."
                )
                .accessibilityIdentifier("settings.help.notifications")
            }
            Toggle(
                "Needs my input, such as a permission prompt",
                isOn: Binding(
                    get: { settingsStore.preferences.notifiesWhenInputNeeded },
                    set: { settingsStore.setNotifiesWhenInputNeeded($0) }
                ))
            Toggle(
                "Finishes its turn",
                isOn: Binding(
                    get: { settingsStore.preferences.notifiesWhenTurnFinishes },
                    set: { settingsStore.setNotifiesWhenTurnFinishes($0) }
                ))
            if isTurnedOffInSystemSettings {
                Text("Notifications for JustSessions are turned off in System Settings > Notifications.")
                    .font(ThemeFont.caption)
                    .foregroundStyle(ThemePalette.warningText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task { await readSystemSettings() }
    }

    private func readSystemSettings() async {
        isTurnedOffInSystemSettings = await SystemPermissionChecker().status(of: .notifications) == .notAllowed
    }
}
