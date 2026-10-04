import SwiftUI

extension HelpKeyboardShortcutGroup {
    /// Every shortcut JustSessions adds. The tab, sidebar, and Settings shortcuts are menu commands
    /// (`WorkspaceTabCommands`, `SidebarToggleCommands`, `AppWideSheetCommands`); Control-Tab is
    /// `WorkspaceTabCycleShortcuts`, and Find is `TranscriptSearchKeyboardShortcuts`.
    static var all: [HelpKeyboardShortcutGroup] {
        [
            HelpKeyboardShortcutGroup(title: "Tabs and windows", shortcuts: [
                HelpKeyboardShortcut(keys: "⌘N", "⌘T", action: "New session"),
                HelpKeyboardShortcut(keys: "⇧⌘N", action: "New window"),
                HelpKeyboardShortcut(keys: "⌘W", action: "Close the tab, or the window when no tabs are open"),
                HelpKeyboardShortcut(keys: "⇧⌘]", "⌃Tab", action: "Next tab"),
                HelpKeyboardShortcut(keys: "⇧⌘[", "⌃⇧Tab", action: "Previous tab"),
                HelpKeyboardShortcut(keys: "⌘1–⌘8", action: "Go to a tab by its position"),
                HelpKeyboardShortcut(keys: "⌘9", action: "Last tab"),
                HelpKeyboardShortcut(keys: "⌃⌘S", action: "Hide or show the sidebar"),
                HelpKeyboardShortcut(keys: "⌘,", action: "Settings"),
            ]),
            HelpKeyboardShortcutGroup(title: "Reading a session", shortcuts: [
                HelpKeyboardShortcut(keys: "⌘F", action: "Find in the conversation"),
                HelpKeyboardShortcut(keys: "⌘G", "Return", action: "Next match"),
                HelpKeyboardShortcut(keys: "⇧⌘G", "⇧Return", action: "Previous match"),
                HelpKeyboardShortcut(keys: "Esc", action: "Close find"),
            ]),
            HelpKeyboardShortcutGroup(title: "Sidebar", shortcuts: [
                HelpKeyboardShortcut(keys: [Text("⌘-click")], action: "Select several sessions or projects"),
                HelpKeyboardShortcut(keys: [Text("⇧-click")], action: "Select a range"),
                HelpKeyboardShortcut(keys: "Esc", action: "Clear the selection, or close search"),
            ]),
            HelpKeyboardShortcutGroup(title: "Terminal", shortcuts: [
                HelpKeyboardShortcut(keys: "⌘C", action: "Copy the selection. Hold ⇧ while dragging to select text."),
            ]),
        ]
    }
}
