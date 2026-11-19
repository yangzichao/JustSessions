import AppKit

extension SelectableTerminalView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        TerminalDroppedFiles.urls(on: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let fileURLs = TerminalDroppedFiles.urls(on: sender.draggingPasteboard)
        guard !fileURLs.isEmpty else { return false }
        onFocus?()
        window?.makeFirstResponder(self)
        if let copyDroppedFilesToHost { return copyDroppedFilesToHost(fileURLs) }
        return typeDroppedPaths(fileURLs.map(\.path))
    }

    @discardableResult
    func typeDroppedPaths(_ paths: [String]) -> Bool {
        let bytes = TerminalFileDropPaste.bytes(forPaths: paths, isBracketed: terminal.bracketedPasteMode)
        send(data: bytes[...])
        return true
    }
}
