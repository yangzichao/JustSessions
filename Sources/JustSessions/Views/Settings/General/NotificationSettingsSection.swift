import SwiftUI

/// The notifications part of the General tab: which moments of a session post a macOS notification.
struct NotificationSettingsSection: View {
    @ObservedObject var settingsStore: SessionNotificationSettingsStore
    /// Whether notifications for the app are turned off in System Settings, which overrides the choices here.
    @State private var isTurnedOffInSystemSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notify me when a session")
                .font(.subheadline.weight(.medium))
            Toggle("Needs my input, such as a permission prompt (not Codex)", isOn: Binding(
                get: { settingsStore.preferences.notifiesWhenInputNeeded },
                set: { settingsStore.setNotifiesWhenInputNeeded($0) }
            ))
            Toggle("Finishes its turn", isOn: Binding(
                get: { settingsStore.preferences.notifiesWhenTurnFinishes },
                set: { settingsStore.setNotifiesWhenTurnFinishes($0) }
            ))
            VStack(alignment: .leading, spacing: 6) {
                Text("Works for Claude Code, Codex, Pi, and OpenCode on this Mac, also while they run in tmux with no tab open. A session whose tab you are looking at sends none. Click a notification to open the session.")
                if isTurnedOffInSystemSettings {
                    Text("Notifications for JustSessions are turned off in System Settings > Notifications.")
                        .foregroundStyle(ThemePalette.warningText)
                }
            }
            .font(.caption)
            .foregroundStyle(ThemePalette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .task { await readSystemSettings() }
    }

    private func readSystemSettings() async {
        isTurnedOffInSystemSettings = await SystemPermissionChecker().status(of: .notifications) == .notAllowed
    }
}
