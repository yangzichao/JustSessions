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
        guard let gridMetrics, gridMetrics.cellWidthPixels > 0, gridMetrics.cellHeightPixels > 0,
            viewport?.columns == gridMetrics.columns, viewport?.rows == gridMetrics.rows,
            let cursor = cursorCell(in: gridMetrics), let screenText = inMemorySession.readViewportText()
        else { return nil }
        return TerminalScreen(lines: screenText.components(separatedBy: "\n"), columnCount: Int(gridMetrics.columns), cursor: cursor)
    }

    func frame(ofCells columns: Range<Int>, inRow row: Int) -> NSRect? {
        guard let gridMetrics, gridMetrics.cellWidthPixels > 0, gridMetrics.cellHeightPixels > 0 else { return nil }
        let scale = window?.backingScaleFactor ?? 1
        let cellWidth = CGFloat(gridMetrics.cellWidthPixels) / scale
        let cellHeight = CGFloat(gridMetrics.cellHeightPixels) / scale
        return NSRect(
            x: CGFloat(columns.lowerBound) * cellWidth,
            y: bounds.height - CGFloat(row + 1) * cellHeight,
            width: CGFloat(columns.count) * cellWidth,
            height: cellHeight
        )
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
    private func cursorCell(in gridMetrics: TerminalGridMetrics) -> TerminalCellPosition? {
        var caretRect = firstRect(forCharacterRange: NSRange(location: 0, length: 0), actualRange: nil)
        if let window {
            caretRect = convert(window.convertFromScreen(caretRect), from: nil)
        }
        let scale = window?.backingScaleFactor ?? 1
        let column = Int(caretRect.minX * scale / CGFloat(gridMetrics.cellWidthPixels))
        let cellBottom = (bounds.height - caretRect.minY) * scale / CGFloat(gridMetrics.cellHeightPixels)
        let row = Int(cellBottom.rounded()) - 1
        guard (0..<Int(gridMetrics.columns)).contains(column), (0..<Int(gridMetrics.rows)).contains(row) else { return nil }
        return TerminalCellPosition(column: column, row: row)
    }
}
