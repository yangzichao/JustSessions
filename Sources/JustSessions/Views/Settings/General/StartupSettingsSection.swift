import SwiftUI

/// The startup part of the General tab: whether JustSessions opens when you log in, and whether it reopens the tabs
/// that were open when it quit.
struct StartupSettingsSection: View {
    let launchAtLoginSettingsStore: LaunchAtLoginSettingsStore
    @ObservedObject var tabReopeningSettingsStore: TabReopeningSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Startup")
                .font(ThemeFont.heading)
            LaunchAtLoginToggle(settingsStore: launchAtLoginSettingsStore)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Toggle("Reopen the tabs that were open when JustSessions quit", isOn: Binding(
                    get: { tabReopeningSettingsStore.reopensTabsAtLaunch },
                    set: { tabReopeningSettingsStore.setReopensTabsAtLaunch($0) }
                ))
                HelpPopoverButton(
                    title: "Reopening tabs",
                    explanation: "A CLI or a plain terminal's shell still running in tmux reattaches. Other sessions resume when you select their tab, including after a Mac restart, and other plain terminals open a new shell in their folder. With this off, quitting ends plain terminals' shells."
                )
                .accessibilityIdentifier("settings.help.reopeningTabs")
            }
        }
    }
}
