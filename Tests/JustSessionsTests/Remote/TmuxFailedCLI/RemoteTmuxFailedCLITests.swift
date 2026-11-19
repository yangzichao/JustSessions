import Foundation
import Testing

@testable import JustSessions

/// A remote tab's CLI that fails in tmux leaves what it printed in the tab, and its status; see
/// `RemoteTmuxAttachScript`. Runs the tab's command against a real tmux on this Mac, with a private tmux server and
/// home folder, and stand-ins for the host's login shell and CLI. Skipped where tmux is not installed.
@Suite(.oneTmuxSandboxAtATime)
struct RemoteTmuxFailedCLITests {
    @Test func aCLIThatFailsAtOnceLeavesWhatItPrintedAndItsStatus() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.replaceCLI(withScript: "#!/bin/sh\necho Starting\necho 'env: node: No such file or directory' >&2\nexit 127\n")
        let tmuxName = TmuxSessionName.unique(for: .claude)

        let client = try sandbox.runClient(tabCommand(sandbox, tmuxName))

        #expect(client.exitStatus == 127)
        // What the tab shows once tmux has given its screen back.
        let afterTmux = try #require(client.output.components(separatedBy: "\u{1B}[?1049l").last)
        #expect(afterTmux.contains("Starting\r\nenv: node: No such file or directory\r\n"))
        #expect(!afterTmux.contains("Pane is dead"))
        #expect(!afterTmux.contains("[detached"))
        #expect(!sandbox.hasTmuxSession(tmuxName))
    }

    @Test func aCLIThatExitsCleanlyEndsItsSessionAsBefore() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.makeCLIExitAtOnce()
        let tmuxName = TmuxSessionName.unique(for: .claude)

        let client = try sandbox.runClient(tabCommand(sandbox, tmuxName))

        #expect(client.exitStatus == 0)
        #expect(sandbox.launchCount == 1)
        #expect(!sandbox.hasTmuxSession(tmuxName))
    }

    /// A detached client's session runs on, so the tab ended without an error, though tmux 3.4's client exits with 1
    /// then; this Mac's tmux may exit with 0.
    @Test func aClientThatDetachesEndsTheTabWithoutAnError() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        let tmuxName = TmuxSessionName.unique(for: .claude)

        let client = try sandbox.startClient(tabCommand(sandbox, tmuxName))
        #expect(sandbox.waitUntil { sandbox.launchCount == 1 })
        _ = sandbox.run("tmux detach-client -s \(ShellQuoting.quoted("=" + tmuxName))")
        #expect(sandbox.waitUntil { !client.isRunning })
        client.waitUntilExit()

        #expect(client.terminationStatus == 0)
        #expect(sandbox.hasTmuxSession(tmuxName))
    }

    /// As when the host's tmux server crashed or was ended: nothing is left to reattach, and the tab says it failed.
    @Test func aClientWhoseServerEndsEndsTheTabWithTmuxsStatus() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        let tmuxName = TmuxSessionName.unique(for: .claude)

        let client = try sandbox.startClient(tabCommand(sandbox, tmuxName))
        #expect(sandbox.waitUntil { sandbox.launchCount == 1 })
        _ = sandbox.run("tmux kill-server")
        #expect(sandbox.waitUntil { !client.isRunning })
        client.waitUntilExit()

        #expect(client.terminationStatus == 1)
    }

    /// As after the tab closed with Keep running: no tab shows the dead pane, so nothing keeps the session.
    @Test func aCLIThatFailsWithNoClientAttachedEndsItsSession() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.replaceCLI(withScript: #"#!/bin/sh\#nwhile [ ! -e "$HOME/fail-now" ]; do sleep 0.1; done; exit 3\#n"#)
        let tmuxName = TmuxSessionName.unique(for: .claude)

        let client = try sandbox.startClient(tabCommand(sandbox, tmuxName))
        #expect(sandbox.waitUntil { sandbox.hasTmuxSession(tmuxName) })
        client.terminate()
        client.waitUntilExit()
        #expect(sandbox.hasTmuxSession(tmuxName))
        _ = sandbox.run("touch \"$HOME/fail-now\"")

        #expect(sandbox.waitUntil { !sandbox.hasTmuxSession(tmuxName) })
    }

    /// As when the connection dropped after the CLI failed, before the script ended its session.
    @Test func aDeadSessionLeftBehindEndsAndTheCLIStartsAgain() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        let tmuxName = TmuxSessionName.unique(for: .claude)
        let target = ShellQuoting.quoted("=" + tmuxName + ":")
        _ = sandbox.run("tmux new-session -d -s \(ShellQuoting.quoted(tmuxName)) 'exit 3' \\; set-option -w remain-on-exit failed")
        #expect(sandbox.waitUntil { sandbox.run("tmux display-message -p -t \(target) '#{pane_dead}'") == "1\n" })

        let client = try sandbox.startClient(tabCommand(sandbox, tmuxName))
        defer { client.terminate() }

        #expect(sandbox.waitUntil { sandbox.launchCount == 1 })
        #expect(sandbox.run("tmux display-message -p -t \(target) '#{pane_dead}'") == "0\n")
    }

    private func tabCommand(_ sandbox: TmuxSandbox, _ tmuxName: String) -> String {
        RemoteCLICommandBuilder.remoteCommand(
            provider: .claude,
            projectPath: sandbox.project.path,
            arguments: ["--resume", "abc"],
            tmuxSessionName: tmuxName
        )
    }
}
