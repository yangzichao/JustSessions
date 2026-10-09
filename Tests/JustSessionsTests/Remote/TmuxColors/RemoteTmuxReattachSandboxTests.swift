import Foundation
import Testing
@testable import JustSessions

/// Runs the reattach command against a real tmux on this Mac, with a private tmux server and home folder, and
/// stand-ins for the host's login shell and CLI. Skipped where tmux is not installed.
struct RemoteTmuxReattachSandboxTests {
    @Test func theClientAttachesAgainAndTheCLIRunsOn() throws {
        guard let tmuxDirectory = TmuxSandbox.installedTmuxDirectory else { return }
        let sandbox = try TmuxSandbox(
            tmuxDirectory: tmuxDirectory,
            tmuxConfiguration: "set-hook -g client-attached 'run-shell \"echo attached >> ~/attaches.log\"'\n"
        )
        defer { sandbox.tearDown() }
        let tmuxName = TmuxSessionName.unique(for: .claude)
        let tabCommand = RemoteCLICommandBuilder.remoteCommand(
            provider: .claude,
            projectPath: sandbox.project.path,
            arguments: ["--resume", "abc"],
            tmuxSessionName: tmuxName
        )
        let attachLog = sandbox.root.appendingPathComponent("attaches.log")
        func attachCount() -> Int {
            ((try? String(contentsOf: attachLog, encoding: .utf8)) ?? "").split(separator: "\n").count
        }
        func attachedClientCount() -> Int {
            sandbox.run("tmux list-clients -t \(ShellQuoting.quoted("=" + tmuxName))").split(separator: "\n").count
        }

        let client = try sandbox.startClient(tabCommand)
        defer { client.terminate() }
        #expect(sandbox.waitUntil { sandbox.launchCount == 1 && attachedClientCount() == 1 })
        let attachesBefore = attachCount()

        let reattach = BoundedProcessRunner.result(
            ofExecutable: "/bin/sh",
            arguments: ["-c", RemoteTmuxCommands.reattachClientsCommand(tmuxName)],
            environment: sandbox.environment,
            includesStandardError: true,
            timeout: 10
        )

        #expect(reattach?.exitStatus == 0, "\(reattach?.output ?? "timed out")")
        #expect(sandbox.waitUntil { attachCount() > attachesBefore && attachedClientCount() == 1 })
        #expect(client.isRunning)
        #expect(sandbox.launchCount == 1)
    }
}
