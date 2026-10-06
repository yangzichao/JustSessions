import Foundation
import Testing
@testable import JustSessions

/// Runs the remote tab's command and the command a new choice sends against a real tmux on this Mac, whose
/// `~/.tmux.conf` sets both prefix keys. Skipped where tmux is not installed.
struct RemoteTmuxPrefixKeysTests {
    @Test func sessionHasNoPrefixKeysUntilTheHostUsesItsOwnAndEachAttachSetsTheChoiceAgain() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: tmuxDirectory, tmuxConfiguration: "set -g prefix C-a\nset -g prefix2 C-q\n")
        defer { sandbox.tearDown() }
        let tmuxName = TmuxSessionName.unique(for: .claude)
        func tabCommand(usingHostPrefix: Bool) -> String {
            RemoteCLICommandBuilder.remoteCommand(
                provider: .claude,
                projectPath: sandbox.project.path,
                arguments: ["--resume", "abc"],
                tmuxSessionName: tmuxName,
                usesHostTmuxPrefix: usingHostPrefix
            )
        }
        func prefixKeys(of sessionName: String) -> [String] {
            let target = ShellQuoting.quoted(sessionName)
            return sandbox.run("tmux show-options -Av -t \(target) prefix \\; show-options -Av -t \(target) prefix2")
                .split(whereSeparator: \.isNewline).map(String.init)
        }

        let firstClient = try sandbox.startClient(tabCommand(usingHostPrefix: false))
        #expect(sandbox.waitUntil { sandbox.launchCount == 1 })
        #expect(prefixKeys(of: tmuxName) == ["None", "None"])

        // Choosing the host's prefix reaches the attached session at once.
        _ = sandbox.run(RemoteTmuxCommands.setPrefixOptionsCommand(usingHostPrefix: true))
        #expect(prefixKeys(of: tmuxName) == ["C-a", "C-q"])

        // Reattaching with the new choice keeps it, and does not start the CLI again.
        firstClient.terminate()
        firstClient.waitUntilExit()
        let secondClient = try sandbox.startClient(tabCommand(usingHostPrefix: true))
        Thread.sleep(forTimeInterval: 1.5)
        #expect(sandbox.launchCount == 1)
        #expect(prefixKeys(of: tmuxName) == ["C-a", "C-q"])

        // Going back to no prefix leaves the host's own tmux sessions alone.
        _ = sandbox.run("tmux new-session -d -s mine 'sleep 60'")
        _ = sandbox.run(RemoteTmuxCommands.setPrefixOptionsCommand(usingHostPrefix: false))
        #expect(prefixKeys(of: tmuxName) == ["None", "None"])
        #expect(prefixKeys(of: "mine") == ["C-a", "C-q"])
        secondClient.terminate()
        secondClient.waitUntilExit()
    }
}
