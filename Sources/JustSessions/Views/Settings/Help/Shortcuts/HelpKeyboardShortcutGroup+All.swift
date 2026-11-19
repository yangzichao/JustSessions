import SwiftUI

extension HelpKeyboardShortcutGroup {
    static var all: [HelpKeyboardShortcutGroup] {
        [
            HelpKeyboardShortcutGroup(
                title: "Tabs and windows",
                shortcuts: [
                    HelpKeyboardShortcut(keys: "⌘N", "⌘T", action: "New session"),
                    HelpKeyboardShortcut(keys: "⇧⌘N", action: "New window"),
                    HelpKeyboardShortcut(keys: "⌥⌘N", action: "Choose a tab to show beside this one"),
                    HelpKeyboardShortcut(keys: "⌘W", action: "Close the tab, or the window when no tabs are open"),
                    HelpKeyboardShortcut(keys: "⇧⌘T", action: "Reopen the tab closed last"),
                    HelpKeyboardShortcut(keys: "⇧⌘]", "⌃Tab", action: "Next tab"),
                    HelpKeyboardShortcut(keys: "⇧⌘[", "⌃⇧Tab", action: "Previous tab"),
                    HelpKeyboardShortcut(keys: "⌘1–⌘8", action: "Go to a tab by its position"),
                    HelpKeyboardShortcut(keys: "⌘9", action: "Last tab"),
                    HelpKeyboardShortcut(keys: "⌘[", action: "Back to the tab or session shown before"),
                    HelpKeyboardShortcut(keys: "⌘]", action: "Forward again"),
                    HelpKeyboardShortcut(keys: "⌘B", action: "Hide or show the sidebar"),
                    HelpKeyboardShortcut(keys: "⌘,", action: "Settings"),
                ]),
            HelpKeyboardShortcutGroup(
                title: "Reading a session",
                shortcuts: [
                    HelpKeyboardShortcut(keys: "⌘F", action: "Find in the conversation"),
                    HelpKeyboardShortcut(keys: "⌘G", "Return", action: "Next match"),
                    HelpKeyboardShortcut(keys: "⇧⌘G", "⇧Return", action: "Previous match"),
                    HelpKeyboardShortcut(keys: "Esc", action: "Close find"),
                    HelpKeyboardShortcut(keys: "⌘D", action: "Bookmark the message you're reading, or remove its bookmark"),
                    HelpKeyboardShortcut(keys: "⇧⌘D", action: "Label and tag the bookmark of the message you're reading"),
                    HelpKeyboardShortcut(keys: "⌘'", action: "Next bookmark"),
                    HelpKeyboardShortcut(keys: "⇧⌘'", action: "Previous bookmark"),
                    HelpKeyboardShortcut(keys: "⌥⌘B", action: "Show all bookmarks, in every session"),
                ]),
            HelpKeyboardShortcutGroup(
                title: "Text size, in the terminals or the conversation shown",
                shortcuts: [
                    HelpKeyboardShortcut(keys: "⌘+", "⌘=", action: "Larger text"),
                    HelpKeyboardShortcut(keys: "⌘−", action: "Smaller text"),
                    HelpKeyboardShortcut(keys: "⌘0", action: "Default size"),
                ]),
            HelpKeyboardShortcutGroup(
                title: "Sidebar",
                shortcuts: [
                    HelpKeyboardShortcut(keys: [Text("⌘-click")], action: "Select several sessions or projects"),
                    HelpKeyboardShortcut(keys: [Text("⇧-click")], action: "Select a range"),
                    HelpKeyboardShortcut(keys: "Esc", action: "Clear the selection, or close search"),
                ]),
            HelpKeyboardShortcutGroup(
                title: "Terminal",
                shortcuts: [
                    HelpKeyboardShortcut(keys: "⌘C", action: "Copy the selection. Hold ⇧ while dragging to select text."),
                    HelpKeyboardShortcut(
                        keys: "⌘A",
                        action: "Select the text in a CLI's prompt, to copy, delete, or replace it. Again, select all of the terminal."
                    ),
                    HelpKeyboardShortcut(keys: "⌘←", "⌘→", action: "Start or end of the line you're typing"),
                    HelpKeyboardShortcut(keys: "⌘⌫", action: "Delete back to the start of the line"),
                    HelpKeyboardShortcut(keys: "⌘Z", action: "Undo your last edit to the line, in Claude Code and shells"),
                    HelpKeyboardShortcut(
                        keys: "⌘F",
                        action: "Find in the terminal. In a tab linked to a session, find in its conversation in a reading window."
                    ),
                    HelpKeyboardShortcut(
                        keys: "⌘D", action: "In a tab linked to a session, bookmark its latest message, or remove its bookmark"),
                    HelpKeyboardShortcut(keys: "⇧⌘D", action: "In a tab linked to a session, label and tag its latest message's bookmark"),
                    HelpKeyboardShortcut(keys: "⌘'", action: "In a tab linked to a session, open its reading window at the next bookmark"),
                    HelpKeyboardShortcut(
                        keys: "⇧⌘'", action: "In a tab linked to a session, open its reading window at the previous bookmark"),
                    HelpKeyboardShortcut(keys: "⌘G", "Return", action: "Older match"),
                    HelpKeyboardShortcut(keys: "⇧⌘G", "⇧Return", action: "Newer match"),
                    HelpKeyboardShortcut(keys: "Esc", action: "Close find, while its field has the keyboard"),
                ]),
        ]
    }
}
