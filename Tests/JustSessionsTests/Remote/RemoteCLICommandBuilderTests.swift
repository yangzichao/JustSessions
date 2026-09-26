import Foundation
import Testing
@testable import JustSessions

struct RemoteCLICommandBuilderTests {
    @Test func buildsAnSSHCommandWithATerminal() {
        let command = RemoteCLICommandBuilder(inheritedEnvironment: ["NO_COLOR": "1", "SSH_AUTH_SOCK": "/tmp/agent"])
            .command(host: "devbox", provider: .codex, projectPath: "/home/me/api", arguments: ["resume", "abc"])

        #expect(command.executablePath == "/usr/bin/ssh")
        #expect(command.arguments.first == "-t")
        #expect(command.arguments.dropLast().last == "devbox")
        #expect(command.arguments.last == #"exec "$SHELL" -lic 'cd '\''/home/me/api'\'' && exec codex '\''resume'\'' '\''abc'\'''"#)
        #expect(command.environment.contains("SSH_AUTH_SOCK=/tmp/agent"))
        #expect(command.environment.contains("TERM=xterm-256color"))
        #expect(!command.environment.contains { $0.hasPrefix("NO_COLOR=") })
    }

    /// Runs the remote command the way the host's shell would, with stand-ins for the login shell and the CLI,
    /// to check that a folder name with a space and a quote survives both levels of quoting.
    @Test func remoteCommandReachesTheCLIInTheProjectFolder() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appendingPathComponent("Bob's paper v2")
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        // `$SHELL -lic <command>`: drop the flags and run the command.
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: bin.appendingPathComponent("login-shell"))
        try writeExecutableScript("#!/bin/sh\npwd -P\nprintf '%s\\n' \"$@\"\n", to: bin.appendingPathComponent("claude"))

        let remoteCommand = RemoteCLICommandBuilder.remoteCommand(
            provider: .claude,
            projectPath: project.path,
            arguments: ["--resume", "id with space"]
        )
        let output = try #require(BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", remoteCommand],
            environment: ["SHELL": bin.appendingPathComponent("login-shell").path, "PATH": bin.path + ":/usr/bin:/bin"],
            timeout: 10
        ))

        // `pwd -P` keeps the `/private` prefix of the temporary folder, which Foundation paths drop.
        let lines = output.split(separator: "\n").map(String.init)
        #expect(lines.first?.hasSuffix("/Bob's paper v2") == true)
        #expect(Array(lines.dropFirst()) == ["--resume", "id with space"])
    }}
