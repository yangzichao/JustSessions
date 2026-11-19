import Foundation
import Testing

@testable import JustSessions

/// A remote Kiro CLI tab's relay, which reads the host's turn markers and puts what the CLI does in the tab's title;
/// see `RemoteKiroActivityRelay`. Runs the tab's command against a real tmux on this Mac, with a private tmux server and
/// home folder, and a `kiro-cli` stand-in that marks its turns as Kiro CLI 2.31.1 does: in a marker named after its TUI,
/// a child process. Skipped where tmux is not installed.
@Suite(.oneTmuxSandboxAtATime)
struct RemoteKiroActivityRelayTests {
    @Test func theTabsTitleSaysWhetherTheCLIHasATurnUnderWay() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.addProgram(named: "kiro-cli", script: Self.kiroMarkingItsTurns)
        let output = sandbox.root.appendingPathComponent("client.log")
        let client = try sandbox.startClient(tabCommand(sandbox), recordingOutputTo: output)
        defer { client.terminate() }

        #expect(sandbox.waitUntil { TerminalTitlesSent.lastActivity(inOutputFile: output, of: .kiro) == .idle })
        _ = sandbox.run(#"touch "$HOME/kiro-turn""#)
        #expect(sandbox.waitUntil { TerminalTitlesSent.lastActivity(inOutputFile: output, of: .kiro) == .working })
        // The turn ended, or Ctrl-C or Esc cancelled it: Kiro takes the marker away either way.
        _ = sandbox.run(#"rm "$HOME/kiro-turn""#)
        #expect(sandbox.waitUntil { TerminalTitlesSent.lastActivity(inOutputFile: output, of: .kiro) == .idle })
    }

    /// On Linux, as the stand-in `uname` says, where `XDG_DATA_HOME` from the host's startup files moves the markers.
    @Test func onLinuxItReadsTheMarkersWhereTheHostsStartupFilesPutThem() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory, loginShellStartup: #"export XDG_DATA_HOME="$HOME/data home""#)
        defer { sandbox.tearDown() }
        try sandbox.addProgram(named: "uname", script: "echo Linux")
        try sandbox.addProgram(named: "kiro-cli", script: Self.kiroMarkingItsTurns)
        let tmuxName = TmuxSessionName.unique(for: .kiro)
        let client = try sandbox.startClient(tabCommand(sandbox, tmuxName: tmuxName))
        defer { client.terminate() }

        _ = sandbox.run(#"touch "$HOME/kiro-turn""#)

        #expect(sandbox.waitUntil { Self.relayedActivity(of: tmuxName, in: sandbox) == "working:" })
        #expect(FileManager.default.fileExists(atPath: sandbox.root.appendingPathComponent("data home/kiro-cli/run/turn-markers").path))
    }

    /// A Kiro too old to keep the folder tells nothing, rather than seeming idle.
    @Test func withoutTheFolderItSaysNothing() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        _ = sandbox.run(#"touch "$HOME/kiro-no-markers""#)
        try sandbox.addProgram(named: "kiro-cli", script: Self.kiroMarkingItsTurns)
        let tmuxName = TmuxSessionName.unique(for: .kiro)
        let client = try sandbox.startClient(tabCommand(sandbox, tmuxName: tmuxName))
        defer { client.terminate() }
        let target = ShellQuoting.quoted("=" + tmuxName + ":")
        #expect(sandbox.waitUntil { sandbox.run("tmux list-clients -t \(target)").contains("/dev/") })

        Thread.sleep(forTimeInterval: 2.5)

        #expect(Self.relayedActivity(of: tmuxName, in: sandbox).isEmpty)
    }

    @Test func itEndsWithTheCLI() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.addProgram(named: "kiro-cli", script: Self.kiroMarkingItsTurns)
        let tmuxName = TmuxSessionName.unique(for: .kiro)
        let client = try sandbox.startClient(tabCommand(sandbox, tmuxName: tmuxName))
        defer { client.terminate() }
        #expect(sandbox.waitUntil { Self.relayedActivity(of: tmuxName, in: sandbox) == "idle:" })
        let target = ShellQuoting.quoted("=" + tmuxName + ":")
        let panePID = try #require(
            Int32(
                sandbox.run("tmux display-message -p -t \(target) '#{pane_pid}'")
                    .trimmingCharacters(in: .newlines)))
        #expect(Self.relayCount(inProcessGroup: panePID) == 1)

        _ = sandbox.run(#"touch "$HOME/kiro-exit""#)

        #expect(sandbox.waitUntil { !sandbox.hasTmuxSession(tmuxName) })
        #expect(sandbox.waitUntil { Self.relayCount(inProcessGroup: panePID) == 0 })
    }

    /// Makes the marker folder where Kiro keeps it, unless `$HOME/kiro-no-markers` is there, and starts a `sleep` as
    /// its TUI. Keeps a marker named after it while `$HOME/kiro-turn` is there, until `$HOME/kiro-exit` appears.
    private static let kiroMarkingItsTurns = #"""
        case $(uname -s) in
        Darwin) markers="$HOME/Library/Application Support/kiro-cli/run/turn-markers" ;;
        *) markers="${XDG_DATA_HOME:-$HOME/.local/share}/kiro-cli/run/turn-markers" ;;
        esac
        [ -e "$HOME/kiro-no-markers" ] || mkdir -p "$markers"
        sleep 600 &
        tui=$!
        while [ ! -e "$HOME/kiro-exit" ]; do
          if [ -e "$HOME/kiro-turn" ] && [ -d "$markers" ]; then
            printf '{"pid":%s,"engine":"v2"}' "$tui" > "$markers/$tui-1792101078428.json"
          else
            rm -f "$markers/$tui-1792101078428.json"
          fi
          sleep 0.1
        done
        rm -f "$markers/$tui-1792101078428.json"
        kill "$tui"
        """#

    private static func relayedActivity(of tmuxName: String, in sandbox: TmuxSandbox) -> String {
        let target = ShellQuoting.quoted("=" + tmuxName + ":")
        return sandbox.run("tmux show-options -wqv -t \(target) \(RemoteCLIActivityTitle.optionName)")
            .trimmingCharacters(in: .newlines)
    }

    /// Relays started in one pane; see `RemoteClaudeActivityRelayTests.relayCount(inProcessGroup:)`.
    private static func relayCount(inProcessGroup processGroupID: Int32) -> Int {
        let processes =
            BoundedProcessRunner.output(
                ofExecutable: "/bin/ps",
                arguments: ["-ax", "-ww", "-o", "pgid=,command="],
                environment: [:],
                timeout: 10
            ) ?? ""
        return processes.split(separator: "\n").filter { line in
            let fields = line.split(separator: " ", maxSplits: 1)
            return fields.count == 2 && Int32(fields[0]) == processGroupID
                && fields[1].trimmingCharacters(in: .whitespaces).hasPrefix("sh -c (")
        }.count
    }

    private func tabCommand(_ sandbox: TmuxSandbox, tmuxName: String = TmuxSessionName.unique(for: .kiro)) -> String {
        RemoteCLICommandBuilder.remoteCommand(
            provider: .kiro,
            projectPath: sandbox.project.path,
            arguments: ["chat"],
            tmuxSessionName: tmuxName
        )
    }
}
