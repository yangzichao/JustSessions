/// A link a CLI broke over rows with newlines of its own. Claude Code, Codex, and other CLIs that lay out their own
/// text wrap a long URL or path at the screen's edge and indent the rest on the next row, and tmux draws the CLI's
/// screen on the tab's terminal the same way, row by row. Ghostty finds links in one row, or in rows it wrapped itself,
/// so a ⌘-click opened only the part clicked. SwiftTerm joins such rows itself.
///
/// As iTerm2 does for full-screen programs, a word that runs to the screen's last cell, or the one before it, which a
/// CLI may keep for padding, goes on in the first word of the next row, after its indentation. The link is then found
/// in the joined word (`JoinedWordLink`). A word that reaches the edge by chance and an unrelated word at the start of
/// the next row are joined too; a CLI's text gives no way to tell them apart.
struct HardWrappedLink {
    /// The whole link.
    let text: String
    /// The row clicked, as the terminal shows it.
    let clickedRowText: String

    /// Nil unless the link at `column` of `row` goes on into a row above or below. `rows` are the screen's rows, top
    /// first, and `columns` its width in cells.
    init?(rows: [String], columns: Int, row: Int, column: Int) {
        guard rows.indices.contains(row) else { return nil }
        let screenRows = rows.map(TerminalScreenRow.init)
        let clickedRow = screenRows[row]
        guard let clickedIndex = clickedRow.characterIndex(atColumn: column),
            let clickedWord = clickedRow.wordRange(around: clickedIndex)
        else { return nil }

        var prefix: [Character] = []
        var rowAbove = row
        var wordStartsItsRow = clickedWord.lowerBound == clickedRow.firstTextIndex
        while wordStartsItsRow, rowAbove > 0, Self.runsToEdge(screenRows[rowAbove - 1], columns: columns),
            let lastWord = screenRows[rowAbove - 1].lastWordRange
        {
            rowAbove -= 1
            prefix = Array(screenRows[rowAbove].characters[lastWord]) + prefix
            wordStartsItsRow = lastWord.lowerBound == screenRows[rowAbove].firstTextIndex
        }

        var suffix: [Character] = []
        var rowBelow = row
        var wordEndsItsRow = clickedWord.upperBound - 1 == clickedRow.lastTextIndex
        while wordEndsItsRow, Self.runsToEdge(screenRows[rowBelow], columns: columns), rowBelow + 1 < screenRows.count,
            let firstWord = screenRows[rowBelow + 1].firstWordRange
        {
            rowBelow += 1
            suffix += screenRows[rowBelow].characters[firstWord]
            wordEndsItsRow = firstWord.upperBound - 1 == screenRows[rowBelow].lastTextIndex
        }

        let clickedPart = Array(clickedRow.characters[clickedWord])
        let joinedWord = prefix + clickedPart + suffix
        let clickedOffset = prefix.count + clickedIndex - clickedWord.lowerBound
        guard let linkRange = JoinedWordLink.linkRange(in: joinedWord, holding: clickedOffset),
            linkRange.lowerBound < prefix.count || linkRange.upperBound > prefix.count + clickedPart.count
        else { return nil }
        text = String(joinedWord[linkRange])
        clickedRowText = rows[row]
    }

    /// The link to open when the engine found `engineLink` at the same place. An OSC 8 hyperlink's target, which the
    /// row doesn't show, wins: the program said where its link goes, as Claude Code does for the URLs in its replies.
    func resolved(engineLink: String?) -> String {
        guard let engineLink, !engineLink.isEmpty, !clickedRowText.contains(engineLink) else { return text }
        return engineLink
    }

    private static func runsToEdge(_ row: TerminalScreenRow, columns: Int) -> Bool {
        row.textWidth >= columns - 1
    }
}
