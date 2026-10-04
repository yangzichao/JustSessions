import SwiftUI

/// The startup part of the General tab: whether JustSessions opens when you log in, and whether it reopens the tabs
/// that were open when it quit.
struct StartupSettingsSection: View {
    let launchAtLoginSettingsStore: LaunchAtLoginSettingsStore
    @ObservedObject var tabReopeningSettingsStore: TabReopeningSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Startup")
                .font(.subheadline.weight(.medium))
            LaunchAtLoginToggle(settingsStore: launchAtLoginSettingsStore)
            Toggle("Reopen the tabs that were open when JustSessions quit", isOn: Binding(
                get: { tabReopeningSettingsStore.reopensTabsAtLaunch },
                set: { tabReopeningSettingsStore.setReopensTabsAtLaunch($0) }
            ))
            Text("A CLI still running in tmux reattaches. Any other tab, such as after a restart of your Mac, resumes its session when you select it. Plain terminals open a new shell in their folder.")
                .font(.caption)
                .foregroundStyle(ThemePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
