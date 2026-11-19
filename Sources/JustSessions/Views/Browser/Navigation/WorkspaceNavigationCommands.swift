import SwiftUI

struct WorkspaceNavigationCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @FocusedValue(\.workspaceNavigation) private var navigation

    var body: some Commands {
        CommandMenu(AppLocalization.string("Go", language: languageStore.language)) {
            Button(AppLocalization.string("Back", language: languageStore.language)) { navigation?.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(navigation?.canGoBack != true)
            Button(AppLocalization.string("Forward", language: languageStore.language)) { navigation?.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(navigation?.canGoForward != true)
        }
    }
}
