struct TerminalScreen {
    let rows: [TerminalScreenRow]
    let columnCount: Int
    let cursor: TerminalCellPosition

    init(rows: [TerminalScreenRow], columnCount: Int, cursor: TerminalCellPosition) {
        self.rows = rows
        self.columnCount = columnCount
        self.cursor = cursor
    }

    init(lines: [String], columnCount: Int, cursor: TerminalCellPosition) {
        self.init(rows: lines.map(TerminalScreenRow.init), columnCount: columnCount, cursor: cursor)
    }
}

struct TerminalCellPosition: Equatable {
    let column: Int
    let row: Int
}
