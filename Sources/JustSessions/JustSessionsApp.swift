import SwiftUI

@main
struct JustSessionsApp: App {
    @NSApplicationDelegateAdaptor(JustSessionsAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "workspace") {
            ContentView()
                .appTheme(from: .shared)
        }
        // The sidebar and detail colors run up behind the traffic lights instead of under a gray title bar.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
        .commands {
            WorkspaceTabCommands()
            CommandGroup(replacing: .help) {
                HelpWindowButton()
                Divider()
                Link("JustSessions on GitHub", destination: AppLinks.githubRepositoryURL)
            }
        }

        Window("JustSessions Help", id: HelpView.windowID) {
            HelpView()
                .appTheme(from: .shared)
        }
        .defaultSize(width: 600, height: 760)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView(
                tabReopeningSettingsStore: .shared,
                appAppearanceStore: .shared,
                appThemeStore: .shared,
                terminalAppearanceStore: .shared,
                notificationSettingsStore: .shared
            )
                .appTheme(from: .shared)
        }
    }
}
