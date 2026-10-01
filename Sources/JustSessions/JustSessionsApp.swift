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
                FeedbackWindowButton()
                Divider()
                Link("JustSessions on GitHub", destination: AppLinks.githubRepositoryURL)
            }
        }

        Window("Feedback", id: FeedbackView.windowID) {
            FeedbackView()
                .appTheme(from: .shared)
        }
        .defaultSize(width: 560, height: 620)
        .windowResizability(.contentSize)

        Settings {
            SettingsView(
                appAppearanceStore: .shared,
                appThemeStore: .shared,
                terminalAppearanceStore: .shared,
                notificationSettingsStore: .shared
            )
                .appTheme(from: .shared)
        }
    }
}
