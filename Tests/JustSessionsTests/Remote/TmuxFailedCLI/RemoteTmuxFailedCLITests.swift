import Foundation
import Testing

@testable import JustSessions

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
