/// Codex's prompt: a first row starting `› `, the next rows indented to line up, then an empty row and the footer
/// rows at the bottom of what Codex draws:
///
///     › first row
///       next row
///
///       GPT-5 high · ~/project
///
/// An empty row may also be an empty line of the prompt, so the prompt ends at the empty row right above the footer.
/// Codex shows `Ask Codex to do anything` or `Ask a follow-up question` while the prompt is empty.
enum CodexPromptRecognizer {
    static let textStartColumn = 2
    static let columnsWithoutText = 3
    static let placeholders: Set<String> = ["Ask Codex to do anything", "Ask a follow-up question"]

    static func prompt(on screen: TerminalScreen) -> CLIPrompt? {
        let rows = screen.rows
        let caretRow = screen.cursor.row
        guard let firstRow = rows[...caretRow].lastIndex(where: isFirstRow),
            let lastRow = lastPromptRow(in: rows), lastRow >= caretRow,
            rows[(firstRow + 1)..<(lastRow + 1)].allSatisfy({ $0.isBlank(beforeColumn: textStartColumn) })
        else { return nil }
        return CLIPrompt(
            lines: (firstRow...lastRow).map { CLIPromptLine(row: $0, of: screen, startColumn: textStartColumn) },
            wrapWidth: screen.columnCount - columnsWithoutText,
            caret: screen.cursor,
            isPlaceholder: placeholders.contains
        )
    }

    private static func isFirstRow(_ row: TerminalScreenRow) -> Bool {
        row.characters.count >= 2 && row.characters[0] == "›" && TerminalScreenRow.isBlank(row.characters[1])
    }

    private static func lastPromptRow(in rows: [TerminalScreenRow]) -> Int? {
        guard let lastRowWithText = rows.lastIndex(where: { $0.firstTextIndex != nil }),
            let separator = rows[...lastRowWithText].lastIndex(where: { $0.firstTextIndex == nil }),
            separator > 0
        else { return nil }
        return separator - 1
    }
}
