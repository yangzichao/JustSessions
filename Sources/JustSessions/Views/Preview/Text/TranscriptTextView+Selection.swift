import AppKit

extension TranscriptTextView {
    var drawsSelectionEmphasized: Bool { selectionCoordinator?.drawsSelectionEmphasized ?? false }

    override func mouseDown(with event: NSEvent) {
        guard let selectionCoordinator else { return super.mouseDown(with: event) }
        if selectionCoordinator.trackSelection(startingWith: event, in: self) { return }
        selectionCoordinator.clearSelection()
        super.mouseDown(with: event)
        selectionCoordinator.adoptSelection(of: self)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let selectionCoordinator, selectionCoordinator.selection?.spansSeveralBlocks == true,
            NSLocationInRange(insertionOffset(atWindowPoint: event.locationInWindow), selectedRange()),
            let menu = menu(for: event)
        else {
            selectionCoordinator?.clearSelection()
            super.rightMouseDown(with: event)
            selectionCoordinator?.adoptSelection(of: self)
            return
        }
        window?.makeFirstResponder(self)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func copy(_ sender: Any?) {
        guard let selectionCoordinator, let text = selectionCoordinator.copiedText() else { return super.copy(sender) }
        selectionCoordinator.pasteboard.clearContents()
        selectionCoordinator.pasteboard.setString(text, forType: .string)
    }

    override func selectAll(_ sender: Any?) {
        guard let selectionCoordinator else { return super.selectAll(sender) }
        selectionCoordinator.selectAll()
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(copy(_:)), selectionCoordinator?.selection?.spansSeveralBlocks == true { return true }
        return super.validateUserInterfaceItem(item)
    }

    override func cancelOperation(_ sender: Any?) {
        selectionCoordinator?.clearSelection()
    }

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        selectionCoordinator?.redrawSelection()
        return didBecome
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        selectionCoordinator?.redrawSelection()
        return didResign
    }

    func insertionOffset(atWindowPoint point: NSPoint) -> Int {
        min(max(0, characterIndexForInsertion(at: convert(point, from: nil))), textLength)
    }

    func openLink(atWindowPoint point: NSPoint) {
        guard let layoutManager, let textContainer, let textStorage, textStorage.length > 0 else { return }
        let viewPoint = convert(point, from: nil)
        let containerPoint = NSPoint(x: viewPoint.x - textContainerOrigin.x, y: viewPoint.y - textContainerOrigin.y)
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
        guard glyphRect.contains(containerPoint) else { return }
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard characterIndex < textStorage.length, let link = textStorage.attribute(.link, at: characterIndex, effectiveRange: nil) else {
            return
        }
        clicked(onLink: link, at: characterIndex)
    }
}
