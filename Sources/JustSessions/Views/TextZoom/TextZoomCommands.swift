import AppKit
import SwiftUI

/// View → Actual Size, Zoom In, and Zoom Out, with Chrome's ⌘0, ⌘+, and ⌘−, size the text you are looking at: the
/// terminals' while a tab shows, otherwise the conversation's. As Chrome keeps one zoom for a site, every terminal
/// shares one size and every conversation another, and both stay after quitting. ⌘= zooms in too, through
/// `ZoomInEqualsKey`. Command shortcuts never reach a tab's CLI.
struct TextZoomCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @FocusedValue(\.textZoomTarget) private var workspaceTarget

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Divider()
            Button(AppLocalization.string("Actual Size", language: languageStore.language)) { zoom(.actualSize) }
                .keyboardShortcut("0", modifiers: .command)
            Button(AppLocalization.string("Zoom In", language: languageStore.language)) { zoom(.zoomIn) }
                .keyboardShortcut("+", modifiers: .command)
            Button(AppLocalization.string("Zoom Out", language: languageStore.language)) { zoom(.zoomOut) }
                .keyboardShortcut("-", modifiers: .command)
        }
    }

    /// Read when the item is chosen. A Read window is AppKit's, outside the workspace windows' scene, and shows a
    /// conversation.
    private func zoom(_ step: TextZoomStep) {
        let target = NSApp.keyWindow?.windowController is SessionReadingWindowController ? .conversation : workspaceTarget
        target?.zoom(step)
    }
}
