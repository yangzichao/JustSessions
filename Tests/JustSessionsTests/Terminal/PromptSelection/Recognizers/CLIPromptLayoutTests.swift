import Testing

@testable import JustSessions

/// ⌘A finds each CLI's prompt on its screen and reads back the text typed in it; see `CLIPromptLayout`. The screens
/// are the CLIs' own, captured in tmux.
struct CLIPromptLayoutTests {
    @Test(arguments: ClaudeCodePromptScreens.all)
    func claudeCodePrompt(_ fixture: PromptScreenFixture) {
        expectPrompt(of: .claudeCode, on: fixture)
    }

    @Test(arguments: CodexPromptScreens.all)
    func codexPrompt(_ fixture: PromptScreenFixture) {
        expectPrompt(of: .codex, on: fixture)
    }

    @Test(arguments: OpenCodePromptScreens.all)
    func openCodePrompt(_ fixture: PromptScreenFixture) {
        expectPrompt(of: .openCode, on: fixture)
    }

    @Test(arguments: PiPromptScreens.all)
    func piPrompt(_ fixture: PromptScreenFixture) {
        expectPrompt(of: .pi, on: fixture)
    }

    @Test(arguments: AntigravityPromptScreens.all)
    func antigravityPrompt(_ fixture: PromptScreenFixture) {
        expectPrompt(of: .antigravity, on: fixture)
    }

    /// A layout with a marker or a box finds no prompt on another CLI's screen. Pi's prompt has neither, so its layout
    /// would read another CLI's prompt between rules, but each tab uses its own CLI's layout.
    @Test func layoutsFindNoPromptOnAnotherCLIsScreen() {
        let fixturesByLayout: [(CLIPromptLayout, [PromptScreenFixture])] = [
            (.claudeCode, ClaudeCodePromptScreens.all),
            (.codex, CodexPromptScreens.all),
            (.openCode, OpenCodePromptScreens.all),
            (.pi, PiPromptScreens.all),
            (.antigravity, AntigravityPromptScreens.all),
        ]
        for (layout, _) in fixturesByLayout where layout != .pi {
            for (otherLayout, fixtures) in fixturesByLayout where otherLayout != layout {
                for fixture in fixtures {
                    #expect(layout.prompt(on: fixture.screen) == nil, "\(layout) on \(otherLayout)'s \(fixture.name)")
                }
            }
        }
    }

    @Test func kiroHasNoLayout() {
        #expect(CLIPromptLayout(provider: .kiro) == nil)
        #expect(CLIPromptLayout(provider: .claude) == .claudeCode)
    }

    @Test func caretOutsideThePromptFindsNone() throws {
        let fixture = try #require(ClaudeCodePromptScreens.all.first { $0.name == "oneLine" })
        let screen = TerminalScreen(lines: fixture.rows, columnCount: 80, cursor: TerminalCellPosition(column: 0, row: 2))

        #expect(CLIPromptLayout.claudeCode.prompt(on: screen) == nil)
    }

    /// An empty prompt holds no text, and one showing the CLI's placeholder holds none either.
    private func expectPrompt(of layout: CLIPromptLayout, on fixture: PromptScreenFixture) {
        let prompt = layout.prompt(on: fixture.screen)
        if fixture.typedText.isEmpty {
            #expect(prompt == nil)
        } else {
            #expect(prompt?.text == fixture.typedText)
        }
    }
}
