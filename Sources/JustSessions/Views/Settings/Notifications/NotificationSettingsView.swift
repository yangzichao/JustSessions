import SwiftUI
import UserNotifications

/// The Notifications tab of Settings: which moments of a session post a macOS notification.
struct NotificationSettingsView: View {
    @ObservedObject var settingsStore: SessionNotificationSettingsStore
    /// Whether notifications for the app are turned off in System Settings, which overrides the choices here.
    @State private var isTurnedOffInSystemSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notify me when a session")
                .font(.subheadline.weight(.medium))
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Needs my input, such as a permission prompt", isOn: Binding(
                    get: { settingsStore.preferences.notifiesWhenInputNeeded },
                    set: { settingsStore.setNotifiesWhenInputNeeded($0) }
                ))
                Toggle("Finishes its turn", isOn: Binding(
                    get: { settingsStore.preferences.notifiesWhenTurnFinishes },
                    set: { settingsStore.setNotifiesWhenTurnFinishes($0) }
                ))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Works for Claude Code and Codex on this Mac, also while they run in tmux with no tab open. A session whose tab you are looking at sends none. Click a notification to open the session.")
                if isTurnedOffInSystemSettings {
                    Text("Notifications for JustSessions are turned off in System Settings > Notifications.")
                        .foregroundStyle(ThemePalette.warning)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 540, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .task { await readSystemSettings() }
    }

    private func readSystemSettings() async {
        guard SessionNotificationCenter.isAvailable else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isTurnedOffInSystemSettings = settings.authorizationStatus == .denied
    }
}
