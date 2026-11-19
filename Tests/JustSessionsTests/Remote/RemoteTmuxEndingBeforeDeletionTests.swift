import Foundation
import Testing

@testable import JustSessions

/// Runs the commands against a real tmux on this Mac, with a private tmux server and home folder, and stand-ins for
/// the host's login shell and CLI; see `TmuxSandbox`. Skipped where tmux is not installed.
@Suite(.oneTmuxSandboxAtATime)
struct RemoteTmuxEndingBeforeDeletionTests {
    /// The CLI takes a second to exit after its terminal hangs up, as a CLI saving on exit might.
    @Test func endingTheSessionReturnsOnceItsCLIHasExited() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        let readyMarker = sandbox.root.appendingPathComponent("ready")
        let exitMarker = sandbox.root.appendingPathComponent("exited")
        try sandbox.replaceCLI(
            withScript:
                "#!/bin/sh\ntrap 'sleep 1; touch \"\(exitMarker.path)\"; exit 0' HUP\ntouch \"\(readyMarker.path)\"\nwhile :; do sleep 0.2; done\n"
        )
        let tmuxName = TmuxSessionName.unique(for: .claude)
        let command = RemoteCLICommandBuilder.remoteCommand(
            provider: .claude,
            projectPath: sandbox.project.path,
            arguments: [],
            tmuxSessionName: tmuxName
        )
        let client = try sandbox.startClient(command)
        defer { client.terminate() }
        try #require(sandbox.waitUntil { FileManager.default.fileExists(atPath: readyMarker.path) })

        _ = sandbox.run(RemoteTmuxCommands.killSessionWaitingForCLIExitCommand(tmuxName, on: "devbox", timeoutSeconds: 5))

        #expect(FileManager.default.fileExists(atPath: exitMarker.path))
        #expect(!sandbox.hasTmuxSession(tmuxName))
    }

    /// The login shell runs a function, so the CLI is the pane's child. Both hang up; the shell exits at once.
    @Test func endingWaitsForACLIAFunctionStartedInTheLoginShell() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(
            tmuxDirectory: tmuxDirectory,
            loginShellStartup: "claude() { command claude --from-function \"$@\"; }\n"
        )
        defer { sandbox.tearDown() }
        let readyMarker = sandbox.root.appendingPathComponent("ready")
        let exitMarker = sandbox.root.appendingPathComponent("exited")
        try sandbox.replaceCLI(
            withScript:
                "#!/bin/sh\ntrap 'sleep 1; touch \"\(exitMarker.path)\"; exit 0' HUP\necho \"$@\" > \"\(readyMarker.path)\"\nwhile :; do sleep 0.2; done\n"
        )
        let tmuxName = TmuxSessionName.unique(for: .claude)
        let command = RemoteCLICommandBuilder.remoteCommand(
            provider: .claude,
            projectPath: sandbox.project.path,
            arguments: [],
            tmuxSessionName: tmuxName
        )
        let client = try sandbox.startClient(command)
        defer { client.terminate() }
        try #require(sandbox.waitUntil { FileManager.default.fileExists(atPath: readyMarker.path) })
        #expect((try? String(contentsOf: readyMarker, encoding: .utf8)) == "--from-function\n")

        _ = sandbox.run(RemoteTmuxCommands.killSessionWaitingForCLIExitCommand(tmuxName, on: "devbox", timeoutSeconds: 5))

        #expect(FileManager.default.fileExists(atPath: exitMarker.path))
        #expect(!sandbox.hasTmuxSession(tmuxName))
    }

    @Test func endingGivesUpOnACLIThatIgnoresTheHangUp() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        let processIDFile = sandbox.root.appendingPathComponent("pid")
        try sandbox.replaceCLI(
            withScript: "#!/bin/sh\ntrap '' HUP\necho $$ > \"\(processIDFile.path)\"\nwhile :; do sleep 0.2; done\n"
        )
        let tmuxName = TmuxSessionName.unique(for: .claude)
        let command = RemoteCLICommandBuilder.remoteCommand(
            provider: .claude,
            projectPath: sandbox.project.path,
            arguments: [],
            tmuxSessionName: tmuxName
        )
        let client = try sandbox.startClient(command)
        defer { client.terminate() }
        try #require(sandbox.waitUntil { ((try? String(contentsOf: processIDFile, encoding: .utf8)) ?? "").hasSuffix("\n") })
        let cliProcessID = try #require(
            Int32((try String(contentsOf: processIDFile, encoding: .utf8)).trimmingCharacters(in: .whitespacesAndNewlines)))
        defer { kill(cliProcessID, SIGKILL) }
        let startedAt = Date()

        _ = sandbox.run(RemoteTmuxCommands.killSessionWaitingForCLIExitCommand(tmuxName, on: "devbox", timeoutSeconds: 2), timeout: 300)

        // The CLI never exits, so returning well before `run`'s 300-second limit means the command gave up on it.
        let elapsed = Date().timeIntervalSince(startedAt)
        #expect(elapsed >= 1 && elapsed < 120, "waited \(elapsed) seconds")
        #expect(kill(cliProcessID, 0) == 0)
    }

    @Test func endingASessionThatNoLongerRunsReturnsAtOnce() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        let startedAt = Date()

        _ = sandbox.run(
            RemoteTmuxCommands.killSessionWaitingForCLIExitCommand(TmuxSessionName.unique(for: .claude), on: "devbox", timeoutSeconds: 5))

        #expect(Date().timeIntervalSince(startedAt) < 3)
    }
}
