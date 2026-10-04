import SwiftUI

struct WorkspaceTabCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.workspaceTabActions) private var actions

    private var closesTab: Bool { (actions?.tabCount ?? 0) > 0 }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(AppLocalization.string("New Session…", language: languageStore.language)) { actions?.newSession() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(actions?.isEnabled != true)
            Button(AppLocalization.string("New Tab…", language: languageStore.language)) { actions?.newSession() }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(actions?.isEnabled != true)
            Button(AppLocalization.string("New Window", language: languageStore.language)) { openWindow(id: "workspace") }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .saveItem) {
            Button(AppLocalization.string(closesTab ? "Close Tab…" : "Close Window", language: languageStore.language)) {
                if closesTab {
                    actions?.closeSelectedTab()
                } else {
                    NSApp.keyWindow?.performClose(nil)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(actions?.isEnabled == false || (closesTab && actions?.hasSelectedTab != true))
        }

        CommandMenu(AppLocalization.string("Tabs", language: languageStore.language)) {
            Button(AppLocalization.string("Previous Tab", language: languageStore.language)) { actions?.selectAdjacentTab(false) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(actions?.isEnabled != true || actions?.tabCount == 0)
            Button(AppLocalization.string("Next Tab", language: languageStore.language)) { actions?.selectAdjacentTab(true) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(actions?.isEnabled != true || actions?.tabCount == 0)

            Divider()

            ForEach(1...9, id: \.self) { shortcutNumber in
                Button(AppLocalization.string(shortcutNumber == 9 ? "Last Tab" : "Tab \(shortcutNumber)", language: languageStore.language)) {
                    actions?.selectTab(shortcutNumber)
                }
                .keyboardShortcut(KeyEquivalent(Character(String(shortcutNumber))), modifiers: .command)
                .disabled(actions?.isEnabled != true || (actions?.tabCount ?? 0) < (shortcutNumber == 9 ? 1 : shortcutNumber))
            }

            Divider()

            Button(AppLocalization.string("Swap Split Sides", language: languageStore.language)) { actions?.swapSplitSides() }
                .disabled(actions?.isEnabled != true || actions?.isSplitShown != true)
            Button(AppLocalization.string("Leave Split View", language: languageStore.language)) { actions?.leaveSplitView() }
                .disabled(actions?.isEnabled != true || actions?.isSplitShown != true)
        }
    }
}
