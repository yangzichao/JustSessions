import AppKit
import ServiceManagement
import SwiftUI

struct LaunchAtLoginSettingsSection: View {
    @ObservedObject var settingsStore: LaunchAtLoginSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Launch JustSessions at login", isOn: Binding(
                get: { settingsStore.launchesAtLogin },
                set: { settingsStore.setLaunchesAtLogin($0) }
            ))
            .accessibilityIdentifier("settings.launchAtLogin")

            Text("Automatically open JustSessions when you log in to your Mac.")
                .font(.caption)
                .foregroundStyle(ThemePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if settingsStore.status == .requiresApproval {
                Text("Allow JustSessions in macOS Login Items to finish enabling automatic launch.")
                    .font(.caption)
                    .foregroundStyle(ThemePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Login Items Settings") {
                    settingsStore.openSystemSettings()
                }
            }

            if let errorDescription = settingsStore.errorDescription {
                Text("Could not change launch at login: \(errorDescription)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { settingsStore.refreshStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            settingsStore.refreshStatus()
        }
    }
}
