import SwiftUI

struct WorkspaceTabCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.workspaceTabActions) private var actions

    private var closesTab: Bool { (actions?.tabCount ?? 0) > 0 }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Session…") { actions?.newSession() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(actions?.isEnabled != true)
            Button("New Tab…") { actions?.newSession() }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(actions?.isEnabled != true)
            Button("New Window") { openWindow(id: "workspace") }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .saveItem) {
            Button(closesTab ? "Close Tab…" : "Close Window") {
                if closesTab {
                    actions?.closeSelectedTab()
                } else {
                    NSApp.keyWindow?.performClose(nil)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(actions?.isEnabled == false || (closesTab && actions?.hasSelectedTab != true))
        }

        CommandMenu("Tabs") {
            Button("Previous Tab") { actions?.selectAdjacentTab(false) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(actions?.isEnabled != true || actions?.tabCount == 0)
            Button("Next Tab") { actions?.selectAdjacentTab(true) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(actions?.isEnabled != true || actions?.tabCount == 0)

            Divider()

            ForEach(1...9, id: \.self) { shortcutNumber in
                Button(shortcutNumber == 9 ? "Last Tab" : "Tab \(shortcutNumber)") {
                    actions?.selectTab(shortcutNumber)
                }
                .keyboardShortcut(KeyEquivalent(Character(String(shortcutNumber))), modifiers: .command)
                .disabled(actions?.isEnabled != true || (actions?.tabCount ?? 0) < (shortcutNumber == 9 ? 1 : shortcutNumber))
            }
        }
    }
}
