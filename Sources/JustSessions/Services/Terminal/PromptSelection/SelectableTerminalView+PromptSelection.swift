import AppKit
import SwiftTerm

extension SelectableTerminalView: PromptSelectableTerminal {
    /// SwiftTerm's screen as it shows it; nil while scrolled back from the bottom. The second cell of a wide character
    /// is left out, and a cell nothing was written to reads as a space, as in Ghostty.
    func screenForPromptSelection() -> TerminalScreen? {
        let terminal = getTerminal()
        guard !canScroll || scrollPosition >= 1 else { return nil }
        let rows = (0..<terminal.rows).map { row in
            let characters = (0..<terminal.cols).compactMap { column -> Character? in
                guard let charData = terminal.getCharData(col: column, row: row), charData.width > 0 else { return nil }
                let character = terminal.getCharacter(for: charData)
                return character == "\0" ? " " : character
            }
            return TerminalScreenRow(String(characters))
        }
        let cursor = terminal.getCursorLocation()
        return TerminalScreen(rows: rows, columnCount: terminal.cols, cursor: TerminalCellPosition(column: cursor.x, row: cursor.y))
    }

    /// The caret is a cell high, and as wide as the character under it, which may take two cells.
    func frame(ofCells columns: Range<Int>, inRow row: Int) -> NSRect? {
        let terminal = getTerminal()
        let cursor = terminal.getCursorLocation()
        let caretCellCount = max(1, Int(terminal.getCharData(col: cursor.x, row: cursor.y)?.width ?? 1))
        let cellWidth = caretFrame.width / CGFloat(caretCellCount)
        let cellHeight = caretFrame.height
        guard cellWidth > 0, cellHeight > 0 else { return nil }
        return NSRect(
            x: CGFloat(columns.lowerBound) * cellWidth,
            y: bounds.height - CGFloat(row + 1) * cellHeight,
            width: CGFloat(columns.count) * cellWidth,
            height: cellHeight
        )
    }

    func typeForPromptSelection(_ keys: String) {
        send(txt: keys)
    }

    func selectAllTerminalText() {
        selectAll()
    }

    var promptSelectionTextStyle: PromptSelectionTextStyle {
        PromptSelectionTextStyle(
            font: font, backgroundColor: selectedTextBackgroundColor, foregroundColor: selectedTextForegroundColor
        )
    }
}
