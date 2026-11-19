struct CLIPrompt: Equatable {
    let lines: [CLIPromptLine]
    let text: String
    let rowCountBelowCaret: Int
    let rowCountAboveCaret: Int

    init?(lines: [CLIPromptLine], wrapWidth: Int, caretRow: Int) {
        guard let firstLine = lines.first, let lastLine = lines.last, lines.contains(where: { !$0.text.isEmpty })
        else { return nil }
        self.lines = lines
        text = CLIPromptLineJoining.text(of: lines, wrapWidth: wrapWidth)
        rowCountBelowCaret = max(0, lastLine.row - caretRow)
        rowCountAboveCaret = max(0, caretRow - firstLine.row)
    }
}

struct CLIPromptLine: Equatable {
    let row: Int
    let startColumn: Int
    let text: String
    let cellCount: Int

    init(row: Int, startColumn: Int, text: String, cellCount: Int) {
        self.row = row
        self.startColumn = startColumn
        self.text = text
        self.cellCount = cellCount
    }

    init(row: Int, of screen: TerminalScreen, startColumn: Int) {
        let rowText = screen.rows[row].text(fromColumn: startColumn)
        self.init(row: row, startColumn: startColumn, text: rowText.text, cellCount: rowText.cellCount)
    }
}
