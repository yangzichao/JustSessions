/// A link a CLI broke over rows with newlines of its own. Claude Code, Codex, and other CLIs that lay out their own
/// text wrap a long URL or path at the screen's edge and indent the rest on the next row, and tmux draws the CLI's
/// screen on the tab's terminal the same way, row by row. Ghostty finds links in one row, or in rows it wrapped itself,
/// so a ⌘-click opened only the part clicked. SwiftTerm joins such rows itself.
struct HardWrappedLink {
    let text: String
    let clickedRowText: String

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

    func resolved(engineLink: String?) -> String {
        guard let engineLink, isOSC8HyperlinkTarget(engineLink) else { return text }
        return engineLink
    }

    private func isOSC8HyperlinkTarget(_ engineLink: String) -> Bool {
        let rowShowsTheLinkItself = clickedRowText.contains(engineLink)
        return !engineLink.isEmpty && !rowShowsTheLinkItself
    }

    private static func runsToEdge(_ row: TerminalScreenRow, columns: Int) -> Bool {
        row.textWidth >= columns - 1
    }
}
