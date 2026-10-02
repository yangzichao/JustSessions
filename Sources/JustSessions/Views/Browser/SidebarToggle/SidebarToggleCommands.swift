import SwiftUI

/// View → Hide Sidebar / Show Sidebar, with the system's ⌃⌘S.
struct SidebarToggleCommands: Commands {
    @FocusedBinding(\.isSidebarHidden) private var isSidebarHidden

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            Button(isSidebarHidden == true ? "Show Sidebar" : "Hide Sidebar") {
                isSidebarHidden?.toggle()
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
            .disabled(isSidebarHidden == nil)
        }
    }
}
