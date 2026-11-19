import SwiftUI

struct SettingsSheet: View {
    @Binding var selectedTab: SettingsTab
    let store: ConversationStore
    let onCheckForUpdates: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SettingsView(
                selectedTab: $selectedTab,
                hosts: store.hosts,
                conversationStore: store,
                languageStore: .shared,
                tabReopeningSettingsStore: .shared,
                launchAtLoginSettingsStore: .shared,
                tabCloseChoiceSettingsStore: .shared,
                plainTerminalCloseChoiceSettingsStore: .shared,
                fileLinkClickSettingsStore: .shared,
                editorStore: .shared,
                appAppearanceStore: .shared,
                appThemeStore: .shared,
                terminalAppearanceStore: .shared,
                terminalEngineStore: .shared,
                terminalOptionKeyStore: .shared,
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
        .environment(
            \.showAppWideSheet,
            ShowAppWideSheetAction { requestedSheet in
                selectedTab = requestedSheet.selectedSettingsTab
            }
        )
        .appLanguage(from: .shared)
    }
}
