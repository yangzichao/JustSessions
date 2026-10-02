import SwiftUI

/// The General tab of Settings: what the app does at launch.
struct GeneralSettingsView: View {
    @ObservedObject var tabReopeningSettingsStore: TabReopeningSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("At launch")
                .font(.subheadline.weight(.medium))
            Toggle("Reopen the tabs that were open when JustSessions quit", isOn: Binding(
                get: { tabReopeningSettingsStore.reopensTabsAtLaunch },
                set: { tabReopeningSettingsStore.setReopensTabsAtLaunch($0) }
            ))
            Text("A CLI still running in tmux reattaches. Any other tab, such as after a restart of your Mac, resumes its session when you select it. Plain terminals open a new shell in their folder.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 540, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        // The window fits the tab, but a taller one shows the theme's surface below it, not the system's tab box.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
