import Foundation
import Testing

@testable import JustSessions

@Suite(.oneTmuxSandboxAtATime)
struct RemotePlainTerminalTmuxTests {
    @Test func theShellRunsOnInTheTabsTmuxSessionAndTheNextClientAttachesToIt() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory)
        defer { sandbox.tearDown() }
        try sandbox.addProgram(
            named: "login-shell",
            script: """
                if [ "$#" = 1 ]; then pwd -P >> "$HOME/shell-starts.log"; env > "$HOME/shell.environment"; exec sleep 600; fi
                shift
                exec /bin/sh -c "$1"
                """)
        let tmuxSessionName = TmuxSessionName.forNewPlainTerminal()
        let tabCommand = RemoteCLICommandBuilder.remotePlainTerminalCommand(
            projectPath: sandbox.project.path,
            tmuxSessionName: tmuxSessionName
        )
        let shellStarts = sandbox.root.appendingPathComponent("shell-starts.log")
        func startedFolders() -> [String] {
            ((try? String(contentsOf: shellStarts, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
        }
        func clientCount() -> Int {
            sandbox.run("tmux list-clients -t \(ShellQuoting.quoted("=" + tmuxSessionName))").split(separator: "\n").count
        }

        let firstClient = try sandbox.startClient(tabCommand)
        #expect(sandbox.waitUntil { startedFolders().count == 1 && clientCount() == 1 })
        #expect(startedFolders().first?.hasSuffix("/Bob's paper") == true)
        let shellEnvironment = try String(contentsOf: sandbox.root.appendingPathComponent("shell.environment"), encoding: .utf8)
        #expect(!shellEnvironment.contains("\(RemoteShellStartup.environmentVariable)="))
        #expect(
            sandbox.run("tmux show-options -v -t \(ShellQuoting.quoted("=" + tmuxSessionName + ":")) history-limit")
                == "\(PlainTerminalTmuxHistoryLimit.lineCount)\n")
        #expect(sandbox.run("tmux show-options -gv history-limit") == "\(PlainTerminalTmuxHistoryLimit.tmuxDefaultLineCount)\n")

        firstClient.terminate()
        firstClient.waitUntilExit()
        #expect(sandbox.waitUntil { clientCount() == 0 })
        #expect(sandbox.hasTmuxSession(tmuxSessionName))

        let nextClient = try sandbox.startClient(tabCommand)
        defer { nextClient.terminate() }
        #expect(sandbox.waitUntil { clientCount() == 1 })
        #expect(startedFolders().count == 1)
    }
}
