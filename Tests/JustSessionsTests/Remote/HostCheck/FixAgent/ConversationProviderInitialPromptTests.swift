import Testing

@testable import JustSessions

/// Each CLI's way to start an interactive session with its first message, as its `--help` lists it: `claude [prompt]`
/// 2.1, `codex [PROMPT]` 0.162, `pi [messages...]` 1.1, `opencode --prompt` 1.18, `agy --prompt-interactive`, and
/// `kiro-cli chat [INPUT]` from Kiro's CLI reference.
struct ConversationProviderInitialPromptTests {
    @Test func eachCLITakesTheFirstMessageItsOwnWay() {
        #expect(ConversationProvider.claude.initialPromptArguments("Fix it") == ["Fix it"])
        #expect(ConversationProvider.codex.initialPromptArguments("Fix it") == ["Fix it"])
        #expect(ConversationProvider.pi.initialPromptArguments("Fix it") == ["Fix it"])
        #expect(ConversationProvider.kiro.initialPromptArguments("Fix it") == ["chat", "Fix it"])
        #expect(ConversationProvider.opencode.initialPromptArguments("Fix it") == ["--prompt", "Fix it"])
        #expect(ConversationProvider.antigravity.initialPromptArguments("Fix it") == ["--prompt-interactive", "Fix it"])
    }

    @Test func aMessageIsNeverTakenForAnOptionOrAFile() {
        #expect(ConversationProvider.claude.initialPromptArguments("--help") == [" --help"])
        #expect(ConversationProvider.pi.initialPromptArguments("@notes.md") == [" @notes.md"])
    }

    @Test func kirosSubcommandIsLeftToAStartCommandOfYourOwn() {
        let arguments = ConversationProvider.kiro.initialPromptArguments("Fix it")
        #expect(ConversationProvider.kiro.argumentsAfterCustomStartCommand(arguments) == ["Fix it"])
    }
}
