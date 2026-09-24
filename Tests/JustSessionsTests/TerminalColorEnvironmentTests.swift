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
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let binaryDirectory = root.appendingPathComponent("bin")
        let projectDirectory = root.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let executable = binaryDirectory.appendingPathComponent("claude")
        try "#!/bin/sh\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
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
}
