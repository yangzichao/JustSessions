import SwiftUI

/// View → Hide Sidebar / Show Sidebar, with the system's ⌃⌘S.
struct SidebarToggleCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @FocusedBinding(\.isSidebarHidden) private var isSidebarHidden

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            Button(AppLocalization.string(isSidebarHidden == true ? "Show Sidebar" : "Hide Sidebar",
                                          language: languageStore.language)) {
                isSidebarHidden?.toggle()
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
            .disabled(isSidebarHidden == nil)
        }
    }
}
