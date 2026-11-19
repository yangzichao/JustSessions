import Foundation

struct AntigravityRemoteSessionMirror {
    var runner = RemoteHostCommandRunner()
    var rsyncRemoteShell = RemoteSessionMirror.rsyncRemoteShell(connectionSharingOptions: [])

    func synchronize(host: String, destination: URL) throws {
        guard let result = runner.run(host, AntigravityRemoteSnapshotCommand.create(on: host), 600) else {
            throw RemoteSessionMirrorError.couldNotRun(host: host)
        }
        if result.exitStatus == 3 {
            try? FileManager.default.removeItem(at: destination)
            return
        }
        if result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus {
            throw RemoteSessionMirrorError.sshFailed(host: host, problem: SSHConnectionProblem(sshOutput: result.output))
        }
        guard result.exitStatus == 0, let snapshotPath = AntigravityRemoteSnapshotCommand.snapshotPath(in: result.output) else {
            throw RemoteSessionMirrorError.rsyncFailed(
                host: host,
                output: "Could not snapshot Antigravity sessions. The SSH host needs python3 and readable session databases.")
        }
        defer { _ = runner.run(host, "rm -rf -- " + ShellQuoting.quoted(snapshotPath), 30) }
        guard
            let result = RemoteSessionMirror.runRsync(
                arguments: RemoteSessionMirror.rsyncArguments(
                    for: .antigravity,
                    source: host + ":" + snapshotPath + "/",
                    destination: destination.path + "/",
                    remoteShell: rsyncRemoteShell
                )
            )
        else { throw RemoteSessionMirrorError.couldNotRun(host: host) }
        guard result.exitStatus == 0 else {
            if result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus {
                throw RemoteSessionMirrorError.sshFailed(host: host, problem: SSHConnectionProblem(sshOutput: result.output))
            }
            throw RemoteSessionMirrorError.rsyncFailed(host: host, output: String(result.output.suffix(500)))
        }
    }
}
