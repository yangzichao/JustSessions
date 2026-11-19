import AppKit
import SwiftUI
import Testing

@testable import JustSessions

@MainActor
struct SettingsTabPageSizeTests {
    @Test func generalAndPermissionsTabsFitTheSharedPageWithoutScrolling() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }

        let tabs: [(name: String, content: AnyView)] = [
            (
                "General",
                AnyView(
                    GeneralSettingsView(
                        hosts: [.thisMac, .ssh("devbox")],
                        conversationStore: ConversationStore(
                            adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false),
                        languageStore: AppLanguageStore(userDefaults: settings.userDefaults),
                        tabReopeningSettingsStore: TabReopeningSettingsStore(userDefaults: settings.userDefaults),
                        launchAtLoginSettingsStore: LaunchAtLoginSettingsStore(),
                        tabCloseChoiceSettingsStore: TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults),
                        plainTerminalCloseChoiceSettingsStore: PlainTerminalCloseChoiceSettingsStore(userDefaults: settings.userDefaults),
                        fileLinkClickSettingsStore: FileLinkClickSettingsStore(userDefaults: settings.userDefaults),
                        editorStore: ExternalEditorStore { _ in nil },
                        notificationSettingsStore: SessionNotificationSettingsStore(userDefaults: settings.userDefaults),
                        onCheckForUpdates: {}
                    ))
            ),
            ("Permissions", AnyView(PermissionsSettingsView())),
        ]

        for tab in tabs {
            let contentHeight = fittingHeight(of: tab.content)
            #expect(
                contentHeight <= SettingsTabPageMetrics.size.height,
                "The \(tab.name) tab is \(contentHeight) pt tall, taller than the \(SettingsTabPageMetrics.size.height) pt page"
            )
        }
    }

    private func fittingHeight(of tabContent: AnyView) -> CGFloat {
        _ = NSApplication.shared
        let hostingView = NSHostingView(
            rootView:
                tabContent
                .padding(SettingsTabPageMetrics.contentPadding)
                .frame(width: SettingsTabPageMetrics.size.width))
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize.height
    }
}
