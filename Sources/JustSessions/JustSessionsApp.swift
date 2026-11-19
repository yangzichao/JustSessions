import SwiftUI

/// The app's start, unless `ssh` started it as its askpass program; see `SSHAskpassRelay`.
@main
enum JustSessionsMain {
    static func main() {
        if let exitStatus = SSHAskpassRelay.exitStatusIfStartedAsAskpass() { exit(exitStatus) }
        JustSessionsApp.main()
    }
}

struct JustSessionsApp: App {
    @StateObject private var languageStore = AppLanguageStore.shared
    @StateObject private var workspaceReads = WorkspaceReadService()
    // periphery:ignore - SwiftUI reads the adaptor to install the delegate.
    @NSApplicationDelegateAdaptor(JustSessionsAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "workspace") {
            ContentView(readService: workspaceReads)
                .handsOverWindowOpening()
                .appTheme(from: .shared)
                .appLanguage(from: languageStore)
        }
        // The sidebar and detail colors run up behind the traffic lights instead of under a gray title bar.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
        .commands {
            WorkspaceNavigationCommands()
            TranscriptBookmarkCommands()
            WorkspaceTabCommands()
            SidebarToggleCommands()
            ConversationMapCommands()
            TextZoomCommands()
            AppWideSheetCommands()
        }
    }
}
