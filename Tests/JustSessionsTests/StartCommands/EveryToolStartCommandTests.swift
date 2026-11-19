import Foundation
import Testing

@testable import JustSessions

struct EveryToolStartCommandTests {
    struct ToolCase: Sendable, CustomTestStringConvertible {
        let provider: ConversationProvider
        let ownWords: [String]
        let resumeArguments: [String]
        var testDescription: String { provider.rawValue }
    }

    static let sessionID = "3f2504e0-4f89-11d3-9a0c-0305e82c3301"

    static let toolCases = [
        ToolCase(provider: .claude, ownWords: ["--dangerously-skip-permissions"], resumeArguments: ["--resume", sessionID]),
        ToolCase(provider: .codex, ownWords: ["--dangerously-bypass-approvals-and-sandbox"], resumeArguments: ["resume", sessionID]),
        ToolCase(provider: .antigravity, ownWords: ["--dangerously-skip-permissions"], resumeArguments: ["--conversation", sessionID]),
        ToolCase(provider: .kiro, ownWords: ["chat", "--trust-all-tools"], resumeArguments: ["--resume-id", sessionID]),
        ToolCase(provider: .opencode, ownWords: ["--model", "anthropic/claude-sonnet"], resumeArguments: ["--session", sessionID]),
        ToolCase(provider: .pi, ownWords: ["--model", "sonnet"], resumeArguments: ["--session", sessionID]),
    ]

    @Test func everyToolHasACase() {
        #expect(Set(Self.toolCases.map(\.provider)) == Set(ConversationProvider.allCases))
    }

    @Test(arguments: toolCases)
    func thisMacResumesWithTheStartCommand(_ toolCase: ToolCase) throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let startCommand = try Self.writeStandIn(for: toolCase, in: root)
        let resolver = NativeCLICommandResolver(
            searchDirectories: ["/usr/bin", "/bin"],
            inheritedEnvironment: ["HOME": root.path],
            liveSessionReporting: nil
        )
        let conversation = Conversation.fixture(provider: toolCase.provider, sessionID: Self.sessionID, projectPath: root.path)

        let command = try resolver.resolve(
            conversation: conversation,
            action: .resume,
            adapter: adapterWithoutSessions(for: toolCase.provider),
            startCommand: startCommand
        )

        let titleArguments = toolCase.provider == .codex ? CodexThreadTitle.launchArguments : []
        #expect(try Self.printedArguments(of: command) == toolCase.ownWords + titleArguments + toolCase.resumeArguments)
    }

    @Test(arguments: toolCases)
    func thisMacStartsANewSessionWithTheStartCommand(_ toolCase: ToolCase) throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let startCommand = try Self.writeStandIn(for: toolCase, in: root)
        let resolver = NativeCLICommandResolver(
            searchDirectories: ["/usr/bin", "/bin"],
            inheritedEnvironment: ["HOME": root.path],
            liveSessionReporting: nil
        )

        let command = try resolver.resolveNewSession(provider: toolCase.provider, projectPath: root.path, startCommand: startCommand)

        let titleArguments = toolCase.provider == .codex ? CodexThreadTitle.launchArguments : []
        #expect(try Self.printedArguments(of: command) == toolCase.ownWords + titleArguments)
    }

    @Test(arguments: toolCases)
    func anSSHHostResumesWithTheStartCommand(_ toolCase: ToolCase) throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let startCommand = try Self.writeStandIn(for: toolCase, in: root)
        let loginShell = try writeExecutableScript(
            "#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: root.appendingPathComponent("login-shell")
        )
        let conversation = Conversation.fixture(provider: toolCase.provider, sessionID: Self.sessionID, projectPath: root.path)

        let remoteCommand = RemoteCLICommandBuilder.remoteCommand(
            provider: toolCase.provider,
            projectPath: root.path,
            arguments: adapterWithoutSessions(for: toolCase.provider).arguments(for: conversation, action: .resume),
            startCommand: startCommand
        )
        let output = try #require(
            BoundedProcessRunner.output(
                ofExecutable: "/bin/sh",
                arguments: ["-c", remoteCommand],
                environment: ["HOME": root.path, "SHELL": loginShell.path, "PATH": "/usr/bin:/bin"],
                timeout: 10
            ))

        let titleArguments = toolCase.provider == .codex ? CodexThreadTitle.launchArguments : []
        #expect(output.split(separator: "\n").map(String.init) == toolCase.ownWords + titleArguments + toolCase.resumeArguments)
    }

    private static func writeStandIn(for toolCase: ToolCase, in home: URL) throws -> String {
        let tools = home.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        try writeExecutableScript(
            "#!/bin/sh\nprintf '%s\\n' \"$@\"\n", to: tools.appendingPathComponent(toolCase.provider.executableName)
        )
        return (["~/tools/\(toolCase.provider.executableName)"] + toolCase.ownWords).joined(separator: " ")
    }

    private static func printedArguments(of command: NativeCLICommand) throws -> [String] {
        let output = try #require(
            BoundedProcessRunner.output(
                ofExecutable: command.executablePath,
                arguments: command.arguments,
                environment: command.environmentVariables,
                timeout: 10
            ))
        return output.split(separator: "\n").map(String.init)
    }
}
