import Foundation
import Testing
@testable import JustSessions

/// A start command is checked where the tool runs before it is kept: its program has to be there.
struct StartCommandCheckTests {
    /// A home folder with `bin/my-claude` in it, which is also on PATH.
    private struct Home {
        let root: URL
        var binPath: String { root.appendingPathComponent("bin").path }

        init() throws {
            root = try makeTemporaryDirectory()
            try FileManager.default.createDirectory(at: root.appendingPathComponent("bin"), withIntermediateDirectories: true)
            try writeExecutableScript("#!/bin/sh\nexit 0\n", to: root.appendingPathComponent("bin/my-claude"))
        }

        func check(remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()) -> StartCommandCheck {
            let resolver = NativeCLICommandResolver(
                searchDirectories: [binPath, "/usr/bin", "/bin"],
                inheritedEnvironment: ["HOME": root.path],
                liveSessionReporting: nil
            )
            return StartCommandCheck(resolver: resolver, remoteRunner: remoteRunner)
        }

        /// Runs the remote command as `ssh` would, in a stand-in for the host's login shell.
        func remoteRunner() throws -> RemoteHostCommandRunner {
            let loginShell = try writeExecutableScript(
                "#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: root.appendingPathComponent("login-shell")
            )
            let environment = ["HOME": root.path, "SHELL": loginShell.path, "PATH": "\(binPath):/usr/bin:/bin"]
            return RemoteHostCommandRunner { _, command, timeout in
                BoundedProcessRunner.result(
                    ofExecutable: "/bin/sh", arguments: ["-c", command], environment: environment, timeout: timeout
                )
            }
        }
    }

    @Test func thisMacFindsTheProgramOnPathOrInHome() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.root) }
        let check = home.check()

        try check.check(#"my-claude --aws-profile "dev""#, on: .thisMac)
        try check.check(#"GREETING=hi ~/bin/my-claude --aws-profile "dev""#, on: .thisMac)
        try check.check("\(home.binPath)/my-claude", on: .thisMac)
    }

    @Test func thisMacRefusesAMissingProgram() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.root) }
        let check = home.check()

        #expect(throws: StartCommandCheckError.missingProgram("~/.toolbox/bin/claude", host: .thisMac)) {
            try check.check(#"~/.toolbox/bin/claude --aws-profile "dev""#, on: .thisMac)
        }
        #expect(throws: StartCommandCheckError.missingProgram("my-claud", host: .thisMac)) {
            try check.check("my-claud", on: .thisMac)
        }
    }

    @Test func commandsThatCannotStartAreRefusedBeforeAnyLookup() throws {
        let check = StartCommandCheck(
            resolver: NativeCLICommandResolver(searchDirectories: [], liveSessionReporting: nil),
            remoteRunner: RemoteHostCommandRunner { _, _, _ in Issue.record("looked up on the host"); return nil }
        )

        #expect(throws: StartCommandCheckError.unclosedQuote) { try check.check(#"claude --aws-profile "dev"#, on: .ssh("cloud")) }
        #expect(throws: StartCommandCheckError.shellOperator(";")) { try check.check("claude; ls", on: .ssh("cloud")) }
        #expect(throws: StartCommandCheckError.noProgram) { try check.check("FOO=bar", on: .ssh("cloud")) }
        // Only the shell knows a program in a variable, so it is kept unchecked.
        try check.check("$HOME/bin/claude", on: .ssh("cloud"))
    }

    @Test func anSSHHostLooksUpTheProgramInItsLoginShell() throws {
        let home = try Home()
        defer { try? FileManager.default.removeItem(at: home.root) }
        let check = home.check(remoteRunner: try home.remoteRunner())

        try check.check("my-claude --dangerously-skip-permissions", on: .ssh("cloud"))
        try check.check(#"~/bin/my-claude --aws-profile "xiliuz-dev""#, on: .ssh("cloud"))
        #expect(throws: StartCommandCheckError.missingProgram("~/.toolbox/bin/claude", host: .ssh("cloud"))) {
            try check.check("~/.toolbox/bin/claude", on: .ssh("cloud"))
        }
    }

    @Test func anSSHHostThatDoesNotAnswerIsReported() throws {
        let unreachable = StartCommandCheck(
            resolver: NativeCLICommandResolver(searchDirectories: [], liveSessionReporting: nil),
            remoteRunner: RemoteHostCommandRunner { _, _, _ in (RemoteHostCommandRunner.connectionFailureExitStatus, "") }
        )
        let stalled = StartCommandCheck(
            resolver: NativeCLICommandResolver(searchDirectories: [], liveSessionReporting: nil),
            remoteRunner: RemoteHostCommandRunner { _, _, _ in nil }
        )

        #expect(throws: StartCommandCheckError.sshFailed(host: "cloud")) { try unreachable.check("claude", on: .ssh("cloud")) }
        #expect(throws: StartCommandCheckError.checkTimedOut(host: .ssh("cloud"))) { try stalled.check("claude", on: .ssh("cloud")) }
    }
}
