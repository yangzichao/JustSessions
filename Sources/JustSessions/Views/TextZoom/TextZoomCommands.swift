import AppKit
import SwiftUI

struct TextZoomCommands: Commands {
    @ObservedObject private var languageStore = AppLanguageStore.shared

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

    private func zoom(_ step: TextZoomStep) {
        let target = TextZoomTargetRegistry.shared.target(keyWindow: NSApp.keyWindow, mainWindow: NSApp.mainWindow) {
            $0.windowController is SessionReadingWindowController
        }
        target?.zoom(step)
    }
}
