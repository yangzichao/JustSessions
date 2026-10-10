import SwiftUI

/// Settings as a sheet on a workspace window: the tabs, then Done.
struct SettingsSheet: View {
    @Binding var selectedTab: SettingsTab
    let onCheckForUpdates: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SettingsView(
                selectedTab: $selectedTab,
                languageStore: .shared,
                tabReopeningSettingsStore: .shared,
                launchAtLoginSettingsStore: .shared,
                tabCloseChoiceSettingsStore: .shared,
                plainTerminalCloseChoiceSettingsStore: .shared,
                appAppearanceStore: .shared,
                appThemeStore: .shared,
                terminalAppearanceStore: .shared,
                terminalEngineStore: .shared,
                notificationSettingsStore: .shared,
                onCheckForUpdates: onCheckForUpdates
            )
            ThemeDivider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(ThemeProminentButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(ThemePalette.contentSurface)
        .background(SettingsSheetTerminationPolicy())
        .environment(\.showAppWideSheet, ShowAppWideSheetAction { requestedSheet in
            selectedTab = requestedSheet.selectedSettingsTab
        })
        .appLanguage(from: .shared)
    }
}
