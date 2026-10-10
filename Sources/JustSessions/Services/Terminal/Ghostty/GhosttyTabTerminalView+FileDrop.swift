import AppKit

/// Files dropped on a Ghostty terminal type their paths into it, as on a SwiftTerm one; see
/// `SelectableTerminalView+FileDrop`. The terminal takes drops only while `acceptsDroppedFiles` is on.
extension GhosttyTabTerminalView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Self.droppedFileURLs(on: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let fileURLs = Self.droppedFileURLs(on: sender.draggingPasteboard)
        guard !fileURLs.isEmpty else { return false }
        // The keyboard follows the paths, so a split pane whose tab is not selected selects it.
        onFocus?()
        window?.makeFirstResponder(self)
        // Each path is its own paste, which Ghostty marks as one when the program turned on bracketed paste. Ghostty
        // takes none before it has a surface.
        var didPasteEveryPath = true
        for path in fileURLs.map(\.path) {
            didPasteEveryPath = paste(text: TerminalFileDropPaste.escapedPath(path) + " ") && didPasteEveryPath
        }
        return didPasteEveryPath
    }

    private static func droppedFileURLs(on pasteboard: NSPasteboard) -> [URL] {
        pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }
}
