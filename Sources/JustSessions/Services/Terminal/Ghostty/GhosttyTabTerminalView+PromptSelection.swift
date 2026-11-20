import AppKit
import GhosttyTerminal

extension GhosttyTabTerminalView: PromptSelectableTerminal {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if window?.firstResponder === self, PromptSelectionKeyAction.isSelectAll(event), promptSelection.selectPrompt() {
            return true
        }
        if sendControlKeyToTmux(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    /// Ghostty's viewport, as `GhosttyTabTerminalView+HardWrappedLinks` reads it. Ghostty reports a new grid to the view
    /// before its terminal takes the new size, so until the two agree, the text isn't laid out at that grid yet.
    func screenForPromptSelection() -> TerminalScreen? {
        guard let cellGrid, let viewport, Int(viewport.columns) == cellGrid.columns, Int(viewport.rows) == cellGrid.rows,
            let cursor = cursorCell(in: cellGrid), let screenText = inMemorySession.readViewportText()
        else { return nil }
        return TerminalScreen(lines: screenText.components(separatedBy: "\n"), columnCount: cellGrid.columns, cursor: cursor)
    }

    func frame(ofCells columns: Range<Int>, inRow row: Int) -> NSRect? {
        cellGrid?.frame(ofColumns: columns, inRow: row)
    }

    func typeForPromptSelection(_ keys: String) {
        sendAsTyped(keys)
    }

    func selectAllTerminalText() {
        super.selectAll(nil)
    }

    var promptSelectionTextStyle: PromptSelectionTextStyle {
        let preferences = appearancePreferences.validated
        let font = preferences.fontFamily.font(size: preferences.fontSize)
        guard let scheme = appliedPalette?.scheme else {
            return PromptSelectionTextStyle(font: font, backgroundColor: .selectedTextBackgroundColor, foregroundColor: .selectedTextColor)
        }
        return PromptSelectionTextStyle(
            font: font,
            backgroundColor: NSColor(hexValue: scheme.selectionBackground),
            foregroundColor: NSColor(hexValue: scheme.readableSelectionForeground)
        )
    }

    override func copy(_ sender: Any?) {
        guard !promptSelection.copySelectedPrompt() else { return }
        super.copy(sender)
    }

    override func selectAll(_ sender: Any?) {
        promptSelection.cancel()
        super.selectAll(sender)
    }

    /// The caret's cell, from where Ghostty puts an input method's window: under the middle of the caret's cell.
    private func cursorCell(in cellGrid: GhosttyZeroPaddingCellGrid) -> TerminalCellPosition? {
        var caretRect = firstRect(forCharacterRange: NSRange(location: 0, length: 0), actualRange: nil)
        if let window {
            caretRect = convert(window.convertFromScreen(caretRect), from: nil)
        }
        return cellGrid.cell(withBottomLeftCornerNear: CGPoint(x: caretRect.minX, y: caretRect.minY))
    }
}
