import Foundation

enum EndedTabScreenText {
    static let maximumLineCount = 40
    static let maximumCharacterCount = 4_000

    static func text(ofRows rows: [String]) -> String? {
        let trimmedRows = rows.map { row in String(row.reversed().drop { $0 == " " }.reversed()) }
        guard let firstTextRow = trimmedRows.firstIndex(where: { !$0.isEmpty }),
            let lastTextRow = trimmedRows.lastIndex(where: { !$0.isEmpty })
        else { return nil }
        let shownRows = trimmedRows[firstTextRow...lastTextRow].suffix(maximumLineCount)
        let text = shownRows.joined(separator: "\n")
        guard text.count > maximumCharacterCount else { return text }
        return String(text.suffix(maximumCharacterCount))
    }
}

extension TerminalSession {
    @MainActor
    var shownTextForHostCheck: String? {
        guard let screen = (terminalView as? PromptSelectableTerminal)?.screenForPromptSelection() else { return nil }
        return EndedTabScreenText.text(ofRows: screen.rows.map { String($0.characters) })
    }
}
