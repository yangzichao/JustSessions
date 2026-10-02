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

            """

        let status = RemoteHostStatusProbe.status(inOutput: output)

        #expect(status.tmuxSessionNames == ["justsessions-claude-01a0cf02-2025-7990-8bb2-80feff2349d4"])
        #expect(status.installedProviders == [.codex, .pi])
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
            arguments: ["-c", RemoteHostStatusProbe.command],
            environment: ["HOME": root.path, "SHELL": bin.appendingPathComponent("login-shell").path, "PATH": "\(bin.path):/usr/bin:/bin"],
            timeout: 10
        )

        // OpenCode runs only on this Mac, so the probe does not look for it.
        #expect(RemoteHostStatusProbe.status(inOutput: try #require(output)).installedProviders == [.codex, .antigravity, .kiro, .pi])
    }
}
