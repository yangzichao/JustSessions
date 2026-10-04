import AppKit
import SwiftUI
import Testing
@testable import JustSessions

@MainActor
struct SettingsTabPageSizeTests {
    /// The Settings window keeps one size because every tab shares it. A tab taller than that scrolls, so this catches
    /// a tab that outgrows it, including the terminal preview at the largest font size.
    @Test func everyTabFitsTheSharedPageAtTheLargestTerminalFontSize() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let appThemeStore = AppThemeStore(userDefaults: settings.userDefaults)
        let terminalAppearanceStore = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        terminalAppearanceStore.setFontSize(TerminalAppearancePreferences.fontSizeRange.upperBound)

        let tabs: [(name: String, content: AnyView)] = [
            ("General", AnyView(GeneralSettingsView(
                languageStore: AppLanguageStore(userDefaults: settings.userDefaults),
                tabReopeningSettingsStore: TabReopeningSettingsStore(userDefaults: settings.userDefaults),
                notificationSettingsStore: SessionNotificationSettingsStore(userDefaults: settings.userDefaults)
            ))),
            ("Appearance", AnyView(AppearanceSettingsView(
                appAppearanceStore: AppAppearanceStore(userDefaults: settings.userDefaults, setApplicationAppearance: { _ in }),
                appThemeStore: appThemeStore,
                terminalAppearanceStore: terminalAppearanceStore
            ))),
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
        let hostingView = NSHostingView(rootView: tabContent
            .padding(SettingsTabPageMetrics.contentPadding)
            .frame(width: SettingsTabPageMetrics.size.width))
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize.height
    }
}
