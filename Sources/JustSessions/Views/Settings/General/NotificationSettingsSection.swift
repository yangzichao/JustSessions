import SwiftUI

/// The notifications part of the General tab: which moments of a session post a macOS notification.
struct NotificationSettingsSection: View {
    @ObservedObject var settingsStore: SessionNotificationSettingsStore
    /// Whether notifications for the app are turned off in System Settings, which overrides the choices here.
    @State private var isTurnedOffInSystemSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Notify me when a session")
                    .font(.subheadline.weight(.medium))
                SettingsHelpButton(
                    title: "Notifications",
                    explanation: "Supports local Claude Code, Codex, Pi, and OpenCode, including sessions running in tmux without an open tab. Sessions you are viewing do not notify you. Click a notification to open its session."
                )
                .accessibilityIdentifier("settings.help.notifications")
            }
            Toggle("Needs my input, such as a permission prompt (not Codex)", isOn: Binding(
                get: { settingsStore.preferences.notifiesWhenInputNeeded },
                set: { settingsStore.setNotifiesWhenInputNeeded($0) }
            ))
            Toggle("Finishes its turn", isOn: Binding(
                get: { settingsStore.preferences.notifiesWhenTurnFinishes },
                set: { settingsStore.setNotifiesWhenTurnFinishes($0) }
            ))
            if isTurnedOffInSystemSettings {
                Text("Notifications for JustSessions are turned off in System Settings > Notifications.")
                    .font(.caption)
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
