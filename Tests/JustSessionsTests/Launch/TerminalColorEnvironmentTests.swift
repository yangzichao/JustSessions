import Foundation
import Testing

@testable import JustSessions

struct TerminalColorEnvironmentTests {
    @Test func removesVariablesThatDisableColor() {
        let cleaned = TerminalColorEnvironment.removingColorDisablingVariables(from: [
            "NO_COLOR": "1",
            "NODE_DISABLE_COLORS": "1",
            "CLICOLOR": "0",
            "FORCE_COLOR": "false",
            "HOME": "/Users/example",
        ])

        #expect(cleaned == ["HOME": "/Users/example"])
    }

    @Test func keepsVariablesThatRequestColor() {
        let environment = ["CLICOLOR": "1", "FORCE_COLOR": "3", "CLICOLOR_FORCE": "1"]

        #expect(TerminalColorEnvironment.removingColorDisablingVariables(from: environment) == environment)
    }

    @Test func spawnedCLIDoesNotInheritNoColorAndStillGetsTruecolorTerm() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let binaryDirectory = root.appendingPathComponent("bin")
        let projectDirectory = root.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let executable = binaryDirectory.appendingPathComponent("claude")
        try writeExecutableScript("#!/bin/sh\nexit 0\n", to: executable)
        let resolver = NativeCLICommandResolver(
            searchDirectories: [binaryDirectory.path],
            inheritedEnvironment: ["NO_COLOR": "1", "CLICOLOR": "0", "HOME": root.path]
        )

        let command = try resolver.resolveNewSession(provider: .claude, projectPath: projectDirectory.path)

        #expect(!command.environment.contains { $0.hasPrefix("NO_COLOR=") })
        #expect(!command.environment.contains { $0.hasPrefix("CLICOLOR=") })
        #expect(command.environment.contains("HOME=\(root.path)"))
        #expect(command.environment.contains("TERM=xterm-256color"))
        #expect(command.environment.contains("COLORTERM=truecolor"))
    }

    /// GhosttyTerminal sets it in the app's own environment; see `GhosttyAppEnvironment`.
    @Test func aCLIDoesNotInheritGhosttysResourcesDirectory() {
        let environment = TerminalColorEnvironment.embeddedTerminalEnvironment(from: [
            "GHOSTTY_RESOURCES_DIR": "/Applications/JustSessions.app/Contents/Resources/Ghostty",
            "HOME": "/Users/example",
        ])

        #expect(environment["GHOSTTY_RESOURCES_DIR"] == nil)
        #expect(environment["HOME"] == "/Users/example")
    }

    /// An app opened from a shell inside a Claude Code session inherits that session's variables; a Claude Code it starts
    /// would take itself for that session's child and save no transcript (`ClaudeCodeSessionEnvironment`).
    @Test func aCLIDoesNotInheritAClaudeCodeSessionTheAppWasOpenedFrom() {
        let parentSession = Dictionary(uniqueKeysWithValues: ClaudeCodeSessionEnvironment.variableNames.map { ($0, "parent") })
        let settings = [
            "CLAUDE_CONFIG_DIR": "/Users/example/.claude-work", "ANTHROPIC_API_KEY": "key", "CLAUDE_CODE_USE_BEDROCK": "1",
            "CLAUDE_CODE_FORCE_SESSION_PERSISTENCE": "1", "HOME": "/Users/example",
        ]

        let environment = TerminalColorEnvironment.embeddedTerminalEnvironment(from: parentSession.merging(settings) { $1 })

        #expect(ClaudeCodeSessionEnvironment.variableNames.allSatisfy { environment[$0] == nil })
        #expect(settings.allSatisfy { environment[$0.key] == $0.value })
        #expect(ClaudeCodeSessionEnvironment.variableNames.contains("CLAUDE_CODE_CHILD_SESSION"))
    }

    /// The tmux session a CLI starts in takes its variables from the tab's command (`ThisMacTmuxServer`), so a Claude Code
    /// started there doesn't see the marker either.
    @Test func aCLIStartedInThisMacsTmuxDoesNotSeeTheChildSessionMarker() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let binaryDirectory = root.appendingPathComponent("bin")
        let projectDirectory = root.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nexit 0\n", to: binaryDirectory.appendingPathComponent("claude"))
        let resolver = NativeCLICommandResolver(
            searchDirectories: [binaryDirectory.path],
            inheritedEnvironment: ["CLAUDECODE": "1", "CLAUDE_CODE_CHILD_SESSION": "1", "CLAUDE_PID": "97524", "HOME": root.path],
            bundledTmuxDirectory: nil
        )

        let command = try resolver.resolveNewSession(provider: .claude, projectPath: projectDirectory.path)
        let tmuxCommand = ThisMacTmuxServer(executablePath: "/usr/bin/true", environment: [:])
            .command(attachingTo: "justsessions-claude-new-test", running: command)

        for name in ["CLAUDECODE", "CLAUDE_CODE_CHILD_SESSION", "CLAUDE_PID"] {
            #expect(!command.environment.contains { $0.hasPrefix(name + "=") })
            #expect(!tmuxCommand.arguments.contains { $0.hasPrefix(name + "=") })
            #expect(!tmuxCommand.environment.contains { $0.hasPrefix(name + "=") })
        }
        #expect(command.environment.contains("HOME=\(root.path)"))
    }
}
