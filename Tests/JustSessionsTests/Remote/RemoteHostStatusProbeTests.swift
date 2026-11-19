import Foundation
import Testing

@testable import JustSessions

struct RemoteHostStatusProbeTests {
    @Test func readsTmuxSessionsAboveTheHeadingAndCLIsBelowIt() {
        let output = """
            Welcome to devbox
            claude
            justsessions-claude-01a0cf02-2025-7990-8bb2-80feff2349d4
            work
            \(RemoteHostStatusProbe.installedCLIsHeading)
            codex
            pi
            opencode
            gemini

            """

        let status = RemoteHostStatusProbe.status(inOutput: output)

        #expect(status.tmuxSessionNames == ["justsessions-claude-01a0cf02-2025-7990-8bb2-80feff2349d4"])
        #expect(status.installedProviders == [.codex, .opencode, .pi])
    }

    /// A shell profile's lines come before the tmux heading, so a name it prints isn't taken for a session.
    @Test func readsTmuxSessionsBetweenTheirHeadingAndTheCLIs() {
        let output = """
            justsessions-codex-new-1a2b3c4d
            \(RemoteHostStatusProbe.tmuxSessionsHeading)
            justsessions-claude-01a0cf02-2025-7990-8bb2-80feff2349d4
            \(RemoteHostStatusProbe.installedCLIsHeading)
            claude

            """

        let status = RemoteHostStatusProbe.status(inOutput: output)

        #expect(status.tmuxSessionNames == ["justsessions-claude-01a0cf02-2025-7990-8bb2-80feff2349d4"])
        #expect(status.tmuxServerProblem == nil)
    }

    /// As after tmux on the host was upgraded while sessions ran.
    @Test func keepsWhatTmuxPrintedWhenItCantReachItsServer() {
        let output = """
            \(RemoteHostStatusProbe.tmuxSessionsHeading)
            protocol version mismatch (client 8, server 7)
            \(RemoteHostStatusProbe.installedCLIsHeading)
            claude

            """

        let status = RemoteHostStatusProbe.status(inOutput: output)

        #expect(status.tmuxSessionNames.isEmpty)
        #expect(status.tmuxServerProblem == "protocol version mismatch (client 8, server 7)")
        #expect(status.installedProviders == [.claude])
    }

    @Test func noTmuxServerRunningIsNoProblem() {
        let output = """
            \(RemoteHostStatusProbe.tmuxSessionsHeading)
            no server running on /tmp/tmux-1000/default
            \(RemoteHostStatusProbe.installedCLIsHeading)

            """

        #expect(RemoteHostStatusProbe.status(inOutput: output).tmuxServerProblem == nil)
    }

    /// A profile that prints the message before the heading isn't tmux's answer.
    @Test func aProfileLineBeforeTheTmuxHeadingIsNoProblem() {
        let output = """
            server exited unexpectedly
            \(RemoteHostStatusProbe.tmuxSessionsHeading)
            \(RemoteHostStatusProbe.installedCLIsHeading)

            """

        #expect(RemoteHostStatusProbe.status(inOutput: output).tmuxServerProblem == nil)
    }

    @Test func noCLIsBelowTheHeadingMeansNoneAreInstalled() {
        let status = RemoteHostStatusProbe.status(inOutput: RemoteHostStatusProbe.installedCLIsHeading + "\n")
        #expect(status.tmuxSessionNames.isEmpty)
        #expect(status.installedProviders == [])
    }

    @Test func missingHeadingLeavesInstalledCLIsUnknown() {
        let status = RemoteHostStatusProbe.status(inOutput: "justsessions-codex-new-1a2b3c4d\n")
        #expect(status.tmuxSessionNames == ["justsessions-codex-new-1a2b3c4d"])
        #expect(status.installedProviders == nil)
    }

    @Test func unreachableHostHasNoStatus() {
        let recorder = RemoteCommandRecorder()
        let status = RemoteHostStatusProbe.status(
            ofHost: "devbox",
            runner: recorder.runner(answering: (RemoteHostCommandRunner.connectionFailureExitStatus, "ssh: connect to host devbox"))
        )
        #expect(status == nil)
        #expect(recorder.commands.map(\.host) == ["devbox"])
    }

    /// An SSH connection ends only once nothing holds the command's output open, as `| cat` here, and an older tmux
    /// server holds a newer client's output open, as the stand-in tmux's `sleep` does.
    @Test func probeEndsThoughTheTmuxServerKeepsTmuxsOutputOpen() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: bin.appendingPathComponent("login-shell"))
        try writeExecutableScript(
            "#!/bin/sh\necho 'server version is too old for client' >&2\nsleep 15 &\n",
            to: bin.appendingPathComponent("tmux")
        )

        let output = BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", "(\(RemoteHostStatusProbe.command(on: "devbox"))) | cat"],
            environment: ["HOME": root.path, "SHELL": bin.appendingPathComponent("login-shell").path, "PATH": "\(bin.path):/usr/bin:/bin"],
            timeout: 10
        )

        #expect(RemoteHostStatusProbe.status(inOutput: try #require(output)).tmuxServerProblem == "server version is too old for client")
    }

    @Test func probeFindsTheCLIsOnTheLoginShellsPath() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: bin.appendingPathComponent("login-shell"))
        for executableName in ["codex", "agy", "kiro-cli", "pi", "opencode"] {
            try writeExecutableScript("#!/bin/sh\nexit 0\n", to: bin.appendingPathComponent(executableName))
        }

        let output = BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", RemoteHostStatusProbe.command(on: "devbox")],
            environment: ["HOME": root.path, "SHELL": bin.appendingPathComponent("login-shell").path, "PATH": "\(bin.path):/usr/bin:/bin"],
            timeout: 10
        )

        #expect(
            RemoteHostStatusProbe.status(inOutput: try #require(output)).installedProviders == [
                .codex, .antigravity, .kiro, .opencode, .pi,
            ])
    }

    @Test func aCLIOnlyInAnInstallFolderStartsFromThereAndTheLoginShellsComesFirst() {
        let nvm = "/home/me/.nvm/versions/node"
        let output = """
            \(RemoteHostStatusProbe.installedCLIsHeading)
            codex
            \(RemoteHostStatusProbe.installFoldersHeading)
            codex \(nvm)/v20.1.0/bin/codex
            claude \(nvm)/v22.3.0/bin/claude
            claude \(nvm)/v9.11.2/bin/claude
            opencode /home/me and you/.opencode/bin/opencode

            """

        let status = RemoteHostStatusProbe.status(inOutput: output)

        #expect(
            status.cliLocations == [
                .codex: .loginShell,
                .claude: .installed(path: "\(nvm)/v22.3.0/bin/claude"),
                .opencode: .installed(path: "/home/me and you/.opencode/bin/opencode"),
            ])
        #expect(status.installedProviders == [.codex, .claude, .opencode])
    }

    @Test func probeFindsACLIInAnInstallFolderTheLoginShellsPathLeavesOut() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bin = root.appendingPathComponent("bin")
        let installFolder = root.appendingPathComponent(".claude/local")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: installFolder, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: bin.appendingPathComponent("login-shell"))
        try writeExecutableScript("#!/bin/sh\nexit 0\n", to: bin.appendingPathComponent("codex"))
        try writeExecutableScript("#!/bin/sh\nexit 0\n", to: installFolder.appendingPathComponent("claude"))

        let output = BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", RemoteHostStatusProbe.command(on: "devbox")],
            environment: ["HOME": root.path, "SHELL": bin.appendingPathComponent("login-shell").path, "PATH": "\(bin.path):/usr/bin:/bin"],
            timeout: 10
        )

        // Other folders, such as `/opt/homebrew/bin`, may have this Mac's own CLIs.
        let probeOutput = try #require(output)
        let cliLocations = try #require(RemoteHostStatusProbe.status(inOutput: probeOutput).cliLocations)
        #expect(cliLocations[.codex] == .loginShell)
        #expect(cliLocations[.claude] == .installed(path: installFolder.appendingPathComponent("claude").path))
    }

    /// With this Mac's bash as the login shell, whose startup file defines them, as a host's might.
    @Test func probeFindsAliasesAndFunctionsOfTheLoginShell() throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        try """
        alias pi="$HOME/tools/pi --from-alias"
        agy() { "$HOME/tools/agy" "$@"; }

        """.write(to: home.appendingPathComponent(".bash_profile"), atomically: true, encoding: .utf8)

        let output = BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", RemoteHostStatusProbe.command(startup: .interactive)],
            environment: ["HOME": home.path, "SHELL": "/bin/bash", "PATH": "/usr/bin:/bin", "TMUX_TMPDIR": home.path],
            timeout: 20
        )

        let probeOutput = try #require(output)
        let cliLocations = try #require(RemoteHostStatusProbe.status(inOutput: probeOutput).cliLocations)
        #expect(cliLocations[.pi] == .loginShell)
        #expect(cliLocations[.antigravity] == .loginShell)
    }
}
