import SwiftUI

@main
struct JustSessionsApp: App {
    @StateObject private var languageStore = AppLanguageStore.shared
    @NSApplicationDelegateAdaptor(JustSessionsAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "workspace") {
            ContentView()
                .appTheme(from: .shared)
                .appLanguage(from: languageStore)
        }
        // The sidebar and detail colors run up behind the traffic lights instead of under a gray title bar.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
        .commands {
            WorkspaceTabCommands()
            SidebarToggleCommands()
            CommandGroup(replacing: .help) {
                HelpWindowButton().appLanguage(from: languageStore)
                Divider()
                Link("JustSessions on GitHub", destination: AppLinks.githubRepositoryURL)
                    .environment(\.locale, languageStore.locale)
            }
        }

        Window(AppLocalization.string("JustSessions Help", language: languageStore.language), id: HelpView.windowID) {
            HelpView()
                .appTheme(from: .shared)
                .appLanguage(from: languageStore)
        }
        .defaultSize(width: 600, height: 680)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView(
                languageStore: languageStore,
                tabReopeningSettingsStore: .shared,
                appAppearanceStore: .shared,
                appThemeStore: .shared,
                terminalAppearanceStore: .shared,
                notificationSettingsStore: .shared
            )
                .appTheme(from: .shared)
                .appLanguage(from: languageStore)
        }
    }
}
