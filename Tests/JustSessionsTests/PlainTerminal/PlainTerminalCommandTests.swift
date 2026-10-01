import Foundation
import Testing
@testable import JustSessions

struct PlainTerminalCommandTests {
    @Test func runsTheLoginShellInTheProjectFolder() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectDirectory = root.appendingPathComponent("it's a project")
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let resolver = NativeCLICommandResolver(
            searchDirectories: [],
            inheritedEnvironment: ["HOME": root.path, "PATH": "/usr/bin:/bin", "NO_COLOR": "1"]
        )

        let command = try resolver.resolvePlainTerminal(projectPath: projectDirectory.path, shellPath: "/bin/zsh")

        #expect(command.executablePath == "/bin/zsh")
        #expect(command.arguments == ["-l"])
        #expect(command.workingDirectory == projectDirectory.path)
        #expect(command.environment.contains("SHELL=/bin/zsh"))
        #expect(command.environment.contains("PATH=/usr/bin:/bin"))
        #expect(command.environment.contains("TERM=xterm-256color"))
        #expect(!command.environment.contains { $0.hasPrefix("NO_COLOR=") })
    }

    @Test func refusesAFolderThatNoLongerExists() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let missingPath = root.appendingPathComponent("gone").path

        #expect(throws: NativeCLICommandError.self) {
            try NativeCLICommandResolver(searchDirectories: []).resolvePlainTerminal(projectPath: missingPath)
        }
    }

    @Test func connectsToTheHostWithoutTmux() {
        let command = RemoteCLICommandBuilder(inheritedEnvironment: [:])
            .plainTerminalCommand(host: "devbox", projectPath: "/home/me/api")

        #expect(command.executablePath == "/usr/bin/ssh")
        #expect(command.arguments.first == "-t")
        #expect(command.arguments.dropLast().last == "devbox")
        #expect(command.arguments.last == #"cd '/home/me/api' && exec "$SHELL" -l"#)
    }

    /// Runs the remote command the way the host's shell would, with a stand-in login shell that reports where it
    /// started and with which flags.
    @Test func remoteCommandStartsTheLoginShellInTheProjectFolder() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appendingPathComponent("Bob's paper v2")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let loginShell = try writeExecutableScript(
            "#!/bin/sh\npwd -P\nprintf '%s\\n' \"$@\"\n",
            to: root.appendingPathComponent("login-shell")
        )

        let output = try #require(BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", RemoteCLICommandBuilder.remotePlainTerminalCommand(projectPath: project.path)],
            environment: ["SHELL": loginShell.path, "PATH": "/usr/bin:/bin"],
            timeout: 10
        ))

        // `pwd -P` keeps the `/private` prefix of the temporary folder, which Foundation paths drop.
        let lines = output.split(separator: "\n").map(String.init)
        #expect(lines.first?.hasSuffix("/Bob's paper v2") == true)
        #expect(Array(lines.dropFirst()) == ["-l"])
    }
}
