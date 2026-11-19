import Foundation

/// The last lines an ended tab's terminal shows, for its host check's report and the prompt of an agent that fixes
/// what the check found, such as tmux's "protocol version mismatch" above ssh's "Connection to … closed."
enum EndedTabScreenText {
    static let maximumLineCount = 40
    /// Long enough for a CLI's error and its context; a whole screen of a wide terminal would crowd out the report.
    static let maximumCharacterCount = 4_000

    /// The rows from the first to the last that show text, at most the last `maximumLineCount` of them and their last
    /// `maximumCharacterCount` characters, without trailing spaces; nil when no row shows text.
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
    /// What the tab's terminal shows now, for Check host on its ended bar; nil while it shows its scrollback, or
    /// shows nothing.
    @MainActor
    var shownTextForHostCheck: String? {
        guard let screen = (terminalView as? PromptSelectableTerminal)?.screenForPromptSelection() else { return nil }
        return EndedTabScreenText.text(ofRows: screen.rows.map { String($0.characters) })
    }
}
