import SwiftUI

/// About JustSessions in the app menu opens the app's own About window instead of macOS's standard panel.
struct AboutCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(AppLocalization.string("About JustSessions", language: languageStore.language)) {
                AboutWindowController.shared.show()
            }
        }
    }
}
