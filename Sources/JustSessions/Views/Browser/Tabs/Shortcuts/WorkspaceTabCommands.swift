import SwiftUI

struct WorkspaceTabCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.workspaceTabActions) private var actions

    private var closesTab: Bool { (actions?.tabCount ?? 0) > 0 }

    /// The split view items, as in Chrome's split view button, act on the shown split, so only while one shows.
    private var isSplitShown: Bool { actions?.isEnabled == true && actions?.isSplitShown == true }

    private var isStacked: Bool { isSplitShown && actions?.shownSplitOrientation == .stacked }

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
            // Chrome's shortcut, and its place in Chrome's File menu.
            Button(AppLocalization.string("Reopen Closed Tab", language: languageStore.language)) { actions?.reopenClosedTab() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(actions?.isEnabled != true || actions?.canReopenClosedTab != true)
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

            // Chrome's shortcut and its Tab menu's name for it.
            Button(AppLocalization.string("Add Tab to New Split View", language: languageStore.language)) { actions?.openSplitChooser() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(actions?.isEnabled != true || actions?.canOpenSplitChooser != true)
            Button(AppLocalization.string("Separate Views", language: languageStore.language)) { actions?.separateShownSplit() }
                .disabled(!isSplitShown)

            Divider()

            Button(AppLocalization.string(isStacked ? "Close Top View" : "Close Left View", language: languageStore.language)) {
                actions?.closeShownSplitView(.left)
            }
            .disabled(!isSplitShown)
            Button(AppLocalization.string(isStacked ? "Close Bottom View" : "Close Right View", language: languageStore.language)) {
                actions?.closeShownSplitView(.right)
            }
            .disabled(!isSplitShown)

            Divider()

            Button(AppLocalization.string("Reverse Views", language: languageStore.language)) { actions?.reverseShownSplit() }
                .disabled(!isSplitShown)
            Button(AppLocalization.string(isStacked ? "Place Views Side by Side" : "Stack Views", language: languageStore.language)) {
                actions?.toggleShownSplitOrientation()
            }
            .disabled(!isSplitShown)
        }
    }
}
