import SwiftUI

struct SidebarToggleCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @FocusedBinding(\.isSidebarHidden) private var isSidebarHidden

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            Button(
                AppLocalization.string(
                    isSidebarHidden == true ? "Show Sidebar" : "Hide Sidebar",
                    language: languageStore.language)
            ) {
                isSidebarHidden?.toggle()
            }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(isSidebarHidden == nil)
        }
    }
}
