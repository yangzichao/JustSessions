/// The keys that edit a CLI's prompt as a whole, which every supported CLI reads the same way: Ctrl-A and Ctrl-E go to
/// the start and end of the line the caret is on, and the arrows step past a line's end into the next one. Each
/// sequence goes a couple of rows further than the prompt has, and deletes more than it holds, since the CLI ignores
/// keys that go past its prompt's ends. A sequence stays short: OpenCode lost the keys after 500 arrows in one write.
enum CLIPromptEditingKeys {
    static let moveToLineStart = "\u{01}"
    static let moveToLineEnd = "\u{05}"
    static let left = "\u{1B}[D"
    static let right = "\u{1B}[C"
    static let deleteBackward = "\u{7F}"

    static let extraRowCount = 2
    static let extraDeleteCount = 16

    static func clearing(_ prompt: CLIPrompt) -> String {
        movingToEnd(of: prompt) + String(repeating: deleteBackward, count: deleteCount(for: prompt))
    }

    static func movingToStart(of prompt: CLIPrompt) -> String {
        moveToLineStart + String(repeating: left + moveToLineStart, count: prompt.rowCountAboveCaret + extraRowCount)
    }

    static func movingToEnd(of prompt: CLIPrompt) -> String {
        moveToLineEnd + String(repeating: right + moveToLineEnd, count: prompt.rowCountBelowCaret + extraRowCount)
    }

    /// A character the CLI deletes at once may be several of the text's scalars, and a row the CLI wrapped may have
    /// dropped a space at its end, so this counts both.
    private static func deleteCount(for prompt: CLIPrompt) -> Int {
        prompt.text.unicodeScalars.count + prompt.lines.count + extraDeleteCount
    }
}
