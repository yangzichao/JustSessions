import SwiftUI

@main
struct JustSessionsApp: App {
    @StateObject private var languageStore = AppLanguageStore.shared
    @NSApplicationDelegateAdaptor(JustSessionsAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "workspace") {
            ContentView()
                .opensWindowsFromDockMenu()
                .appTheme(from: .shared)
                .appLanguage(from: languageStore)
        }
        // The sidebar and detail colors run up behind the traffic lights instead of under a gray title bar.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
        .commands {
            WorkspaceTabCommands()
            SidebarToggleCommands()
            AppWideSheetCommands()
        }
    }
}
