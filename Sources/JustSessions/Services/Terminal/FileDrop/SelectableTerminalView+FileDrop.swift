import AppKit

/// Files dropped on a terminal type their paths into it, as in Terminal.app, so the CLI can read them. The terminal
/// takes drops only while `acceptsDroppedFiles` is on.
extension SelectableTerminalView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Self.droppedFileURLs(on: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let fileURLs = Self.droppedFileURLs(on: sender.draggingPasteboard)
        guard !fileURLs.isEmpty else { return false }
        // The keyboard follows the paths, so a split pane whose tab is not selected selects it.
        onFocus?()
        window?.makeFirstResponder(self)
        let bytes = TerminalFileDropPaste.bytes(
            forPaths: fileURLs.map(\.path),
            isBracketed: terminal.bracketedPasteMode
        )
        send(data: bytes[...])
        return true
    }

    private static func droppedFileURLs(on pasteboard: NSPasteboard) -> [URL] {
        pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }
}
