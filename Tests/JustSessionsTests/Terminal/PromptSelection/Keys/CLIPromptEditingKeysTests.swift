import Testing

@testable import JustSessions

struct CLIPromptEditingKeysTests {
    private let prompt = CLIPrompt(
        lines: [
            CLIPromptLine(row: 4, startColumn: 2, text: "kiwi", cellCount: 4),
            CLIPromptLine(row: 5, startColumn: 2, text: "mango", cellCount: 5),
        ],
        wrapWidth: 76,
        caretRow: 4
    )!

    @Test func clearingGoesToTheEndThenDeletesEverything() {
        let rowSteps = String(repeating: "\u{1B}[C\u{05}", count: 1 + CLIPromptEditingKeys.extraRowCount)
        let deletes = String(repeating: "\u{7F}", count: "kiwi\nmango".count + 2 + CLIPromptEditingKeys.extraDeleteCount)

        #expect(prompt.text == "kiwi\nmango")
        #expect(CLIPromptEditingKeys.clearing(prompt) == "\u{05}" + rowSteps + deletes)
    }

    @Test func movingToTheStartStepsBackOverTheRowsAbove() {
        let rowSteps = String(repeating: "\u{1B}[D\u{01}", count: CLIPromptEditingKeys.extraRowCount)

        #expect(CLIPromptEditingKeys.movingToStart(of: prompt) == "\u{01}" + rowSteps)
    }

    /// OpenCode lost the keys after 500 arrows sent at once.
    @Test func aLongPromptsKeysStayFewArrows() {
        let lines = (0..<20).map { CLIPromptLine(row: $0, startColumn: 2, text: String(repeating: "x", count: 70), cellCount: 70) }
        let longPrompt = CLIPrompt(lines: lines, wrapWidth: 76, caretRow: 0)!

        #expect(CLIPromptEditingKeys.clearing(longPrompt).components(separatedBy: "\u{1B}[C").count - 1 == 21)
    }
}
