import SwiftUI

/// View → Hide Sidebar / Show Sidebar, with ⌘B, as in code editors such as VS Code. Command shortcuts never reach a
/// tab's CLI, so this leaves Control-B to it.
struct SidebarToggleCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @FocusedBinding(\.isSidebarHidden) private var isSidebarHidden

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            Button(AppLocalization.string(isSidebarHidden == true ? "Show Sidebar" : "Hide Sidebar",
                                          language: languageStore.language)) {
                isSidebarHidden?.toggle()
            }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(isSidebarHidden == nil)
        }
    }
}
