/// A prompt between two rules of `─` across the screen, as Claude Code, Pi, and Antigravity draw it:
///
///     ────────────────────
///     ❯ first row
///       next row
///     ────────────────────
///
/// Claude Code starts the first row with `❯` (or `!` in bash mode) and Antigravity with `>`; both indent the other rows
/// to line up. Pi draws no marker. Claude Code shows `Try "…"` while the prompt is empty.
struct RuledPromptRecognizer: Sendable {
    let firstRowMarkers: Set<Character>
    let textStartColumn: Int
    let columnsWithoutText: Int
    let isPlaceholder: @Sendable (String) -> Bool

    static let claudeCode = RuledPromptRecognizer(
        firstRowMarkers: ["❯", "!"], textStartColumn: 2, columnsWithoutText: 4,
        isPlaceholder: { $0.hasPrefix("Try \"") && $0.hasSuffix("\"") }
    )
    static let pi = RuledPromptRecognizer(firstRowMarkers: [], textStartColumn: 0, columnsWithoutText: 1, isPlaceholder: { _ in false })
    static let antigravity = RuledPromptRecognizer(
        firstRowMarkers: [">"], textStartColumn: 2, columnsWithoutText: 3, isPlaceholder: { _ in false }
    )

    func prompt(on screen: TerminalScreen) -> CLIPrompt? {
        let caretRow = screen.cursor.row
        guard let topRule = screen.rows[..<caretRow].lastIndex(where: { isRule($0, on: screen) }),
            let bottomRule = screen.rows[(caretRow + 1)...].firstIndex(where: { isRule($0, on: screen) })
        else { return nil }
        let rows = (topRule + 1)..<bottomRule
        guard startsWithMarker(screen.rows[rows.lowerBound]),
            rows.dropFirst().allSatisfy({ screen.rows[$0].isBlank(beforeColumn: textStartColumn) })
        else { return nil }
        return CLIPrompt(
            lines: rows.map { CLIPromptLine(row: $0, of: screen, startColumn: textStartColumn) },
            wrapWidth: screen.columnCount - columnsWithoutText,
            caret: screen.cursor,
            isPlaceholder: isPlaceholder
        )
    }

    private func isRule(_ row: TerminalScreenRow, on screen: TerminalScreen) -> Bool {
        guard let first = row.firstTextIndex, let last = row.lastTextIndex else { return false }
        return row.characters[first...last].allSatisfy { $0 == "─" } && last - first + 1 >= screen.columnCount / 2
    }

    private func startsWithMarker(_ row: TerminalScreenRow) -> Bool {
        guard !firstRowMarkers.isEmpty else { return true }
        guard let marker = row.characters.first, firstRowMarkers.contains(marker) else { return false }
        // Claude Code puts a no-break space after its marker.
        return row.characters.dropFirst().prefix(textStartColumn - 1).allSatisfy(TerminalScreenRow.isBlank)
    }
}
