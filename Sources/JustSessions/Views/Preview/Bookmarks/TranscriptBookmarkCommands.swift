import AppKit
import SwiftUI

/// The target is read when an item is chosen, as View → Zoom's is (`TextZoomCommands`): a focused value is missing in
/// a reading window. Items are always enabled, since a Commands body follows neither the key window nor the scroll
/// position.
struct TranscriptBookmarkCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared

    var body: some Commands {
        CommandMenu(AppLocalization.string("Bookmarks", language: languageStore.language)) {
            Button(AppLocalization.string("Add or Remove Bookmark", language: languageStore.language)) { target?.toggleBookmark() }
                .keyboardShortcut("d", modifiers: .command)
            Button(AppLocalization.string("Edit Bookmark…", language: languageStore.language)) { target?.editBookmark() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Divider()
            Button(AppLocalization.string("Next Bookmark", language: languageStore.language)) { target?.goToAdjacentBookmark(true) }
                .keyboardShortcut("'", modifiers: .command)
            Button(AppLocalization.string("Previous Bookmark", language: languageStore.language)) { target?.goToAdjacentBookmark(false) }
                .keyboardShortcut("'", modifiers: [.command, .shift])
            Divider()
            Button(AppLocalization.string("Show All Bookmarks…", language: languageStore.language)) { AllBookmarksCommand.show() }
                .keyboardShortcut("b", modifiers: [.command, .option])
        }
    }

    private var target: TranscriptBookmarkCommandTarget? {
        TranscriptBookmarkTargetRegistry.shared.target(keyWindow: NSApp.keyWindow)
    }
}
