import Testing

@testable import JustSessions

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

    private func expectPrompt(of layout: CLIPromptLayout, on fixture: PromptScreenFixture) {
        let prompt = layout.prompt(on: fixture.screen)
        if fixture.typedText.isEmpty {
            #expect(prompt == nil)
        } else {
            #expect(prompt?.text == fixture.typedText)
        }
    }
}
