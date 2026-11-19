import Testing

@testable import JustSessions

/// A CLI's screen captured with text typed in its prompt: what `tmux capture-pane` read, with the cursor it reported.
/// The scenarios type an empty prompt, one and two lines, a sentence the CLI wraps, a word longer than a row, wide
/// characters, short lines that would fit in one row, a blank line between two, and two lines with the caret moved up.
struct PromptScreenFixture: CustomTestStringConvertible {
    let name: String
    let typedText: String
    let columnCount: Int
    let cursor: TerminalCellPosition
    let rows: [String]

    var screen: TerminalScreen { TerminalScreen(lines: rows, columnCount: columnCount, cursor: cursor) }

    var testDescription: String { name }
}
