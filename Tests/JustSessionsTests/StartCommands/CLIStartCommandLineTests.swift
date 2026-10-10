import Foundation
import Testing
@testable import JustSessions

/// A start command runs as a shell reads it, with the app's arguments after it, on this Mac and on SSH hosts alike.
struct CLIStartCommandLineTests {
    /// Prints the variable a start command can set, then each argument on a line of its own.
    private static let argumentPrinter = "#!/bin/sh\nprintf '%s\\n' \"greeting=$GREETING\" \"$@\"\n"
    private static let startCommand = #"GREETING=hi ~/tools/my-claude --aws-profile "dev box""#

    @Test func thisMacRunsTheStartCommandWithTheAppsArgumentsAfterIt() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("tools"), withIntermediateDirectories: true)
        try writeExecutableScript(Self.argumentPrinter, to: root.appendingPathComponent("tools/my-claude"))
        // No `claude` on the search path: a start command of your own is not looked up.
        let resolver = NativeCLICommandResolver(
            searchDirectories: ["/usr/bin", "/bin"],
            inheritedEnvironment: ["HOME": root.path]
        )
        let conversation = Conversation.fixture(sessionID: "id with space", projectPath: project.path)

        let command = try resolver.resolve(
            conversation: conversation, action: .resume, adapter: ClaudeAdapter(), startCommand: Self.startCommand
        )
        let output = try #require(BoundedProcessRunner.output(
            ofExecutable: command.executablePath,
            arguments: command.arguments,
            environment: command.environmentVariables,
            timeout: 10
        ))

        #expect(command.executablePath == "/bin/sh")
        #expect(output.split(separator: "\n") == ["greeting=hi", "--aws-profile", "dev box", "--resume", "id with space"])
    }

    @Test func thisMacStartsTheToolsOwnExecutableWithoutAStartCommand() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let claude = try writeExecutableScript("#!/bin/sh\nexit 0\n", to: root.appendingPathComponent("claude"))
        let resolver = NativeCLICommandResolver(searchDirectories: [root.path])

        let command = try resolver.resolveNewSession(provider: .claude, projectPath: root.path, startCommand: "  ")

        #expect(command.executablePath == claude.path)
        #expect(command.arguments.isEmpty)
    }

    /// Runs the remote command the way the host's shell would, with a stand-in for the login shell.
    @Test func anSSHHostRunsTheStartCommandWithTheAppsArgumentsAfterIt() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("tools"), withIntermediateDirectories: true)
        // `$SHELL -lic <command>`: drop the flags and run the command.
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: bin.appendingPathComponent("login-shell"))
        try writeExecutableScript(Self.argumentPrinter, to: root.appendingPathComponent("tools/my-claude"))

        let remoteCommand = RemoteCLICommandBuilder.remoteCommand(
            provider: .claude,
            projectPath: root.path,
            arguments: ["--resume", "id with 'quote'"],
            startCommand: Self.startCommand
        )
        let output = try #require(BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", remoteCommand],
            environment: [
                "HOME": root.path,
                "SHELL": bin.appendingPathComponent("login-shell").path,
                "PATH": bin.path + ":/usr/bin:/bin",
            ],
            timeout: 10
        ))

        #expect(output.split(separator: "\n") == ["greeting=hi", "--aws-profile", "dev box", "--resume", "id with 'quote'"])
    }

    @Test func anSSHHostStartsTheToolsOwnExecutableWithoutAStartCommand() {
        let remoteCommand = RemoteCLICommandBuilder.remoteCommand(
            provider: .codex, projectPath: "/home/me/api", arguments: ["resume", "abc"], startCommand: ""
        )

        #expect(remoteCommand == #"exec /usr/bin/env JUSTSESSIONS=1 COLORTERM=truecolor "$SHELL" -lic 'cd '\''/home/me/api'\'' && exec codex '\''resume'\'' '\''abc'\'''"#)
    }
}
