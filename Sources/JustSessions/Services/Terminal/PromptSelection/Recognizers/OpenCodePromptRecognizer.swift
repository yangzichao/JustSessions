/// OpenCode's prompt: a box with `┃` down its left side and `╹▀▀▀` along its bottom. An empty row tops the box, then
/// the prompt's rows, an empty row, and the row naming the agent and model:
///
///        ┃
///        ┃  first row
///        ┃  next row
///        ┃
///        ┃  Build · model
///        ╹▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
///
/// The text starts three cells after the `┃`, and leaves two cells free before the box's right edge, where `▀` ends.
/// OpenCode shows `Ask anything… "…"` while the prompt is empty.
enum OpenCodePromptRecognizer {
    static let placeholderPrefix = "Ask anything… \""
    private static let emptyRowsAtTheBoxTop = 1
    private static let rowsBetweenThePromptAndTheBottomBorder = 2
    private static let cellsFromTheLeftBorderToTheText = 3
    private static let freeCellsBeforeTheRightEdge = 2

    static func prompt(on screen: TerminalScreen) -> CLIPrompt? {
        let rows = screen.rows
        let caretRow = screen.cursor.row
        guard let bottomRow = rows[(caretRow + 1)...].firstIndex(where: { $0.firstTextCharacter == "╹" }),
            let borderIndex = rows[bottomRow].firstTextIndex
        else { return nil }
        let borderColumn = rows[bottomRow].startColumn(ofCharacterAt: borderIndex)
        let topRow = rows[..<bottomRow].lastIndex { $0.character(atColumn: borderColumn) != "┃" }.map { $0 + 1 } ?? 0
        let promptRows = (topRow + emptyRowsAtTheBoxTop)..<(bottomRow - rowsBetweenThePromptAndTheBottomBorder)
        guard promptRows.contains(caretRow) else { return nil }
        let textStartColumn = borderColumn + cellsFromTheLeftBorderToTheText
        return CLIPrompt(
            lines: promptRows.map { CLIPromptLine(row: $0, of: screen, startColumn: textStartColumn) },
            wrapWidth: rows[bottomRow].textWidth - textStartColumn - freeCellsBeforeTheRightEdge,
            caret: screen.cursor,
            isPlaceholder: { $0.hasPrefix(placeholderPrefix) }
        )
    }
}
