import Testing

@testable import JustSessions

/// A CLI's screen captured with text typed in its prompt: what `tmux capture-pane` read, with the cursor it reported.
struct PromptScreenFixture: CustomTestStringConvertible {
    let name: String
    let typedText: String
    let columnCount: Int
    let cursor: TerminalCellPosition
    let rows: [String]

    var screen: TerminalScreen { TerminalScreen(lines: rows, columnCount: columnCount, cursor: cursor) }

    var testDescription: String { name }
}
