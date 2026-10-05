import Foundation
import Testing
@testable import JustSessions

struct CLIStartCommandsTests {
    @Test func keepsACommandPerToolAndHost() {
        var commands = CLIStartCommands()

        commands.setCommand("~/.toolbox/bin/claude --aws-profile \"dev\"", for: .claude, on: .ssh("cloud"))

        #expect(commands.customCommand(for: .claude, on: .ssh("cloud")) == "~/.toolbox/bin/claude --aws-profile \"dev\"")
        #expect(commands.customCommand(for: .claude, on: .thisMac) == nil)
        #expect(commands.customCommand(for: .claude, on: .ssh("devbox")) == nil)
        #expect(commands.customCommand(for: .codex, on: .ssh("cloud")) == nil)
    }

    @Test func anEmptyCommandOrTheExecutableNameAloneGoesBackToTheExecutable() {
        var commands = CLIStartCommands()
        commands.setCommand("claude --dangerously-skip-permissions", for: .claude, on: .thisMac)
        commands.setCommand("codex --yolo", for: .codex, on: .thisMac)

        commands.setCommand("  ", for: .claude, on: .thisMac)
        commands.setCommand(" codex ", for: .codex, on: .thisMac)

        #expect(commands == CLIStartCommands())
    }

    @Test func aPastedCommandBecomesOneLine() {
        var commands = CLIStartCommands()

        commands.setCommand("  claude\n--dangerously-skip-permissions\n", for: .claude, on: .thisMac)

        #expect(commands.customCommand(for: .claude, on: .thisMac) == "claude --dangerously-skip-permissions")
    }

    @Test func survivesARestart() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        var commands = CLIStartCommands()
        commands.setCommand("pi --model sonnet", for: .pi, on: .ssh("devbox"))

        commands.save(to: settings.userDefaults)

        #expect(CLIStartCommands.load(from: settings.userDefaults) == commands)
    }
}
