import Foundation

/// Copies an SSH host's OpenCode sessions. Its database also holds OpenCode's accounts and credentials, so it is
/// never copied whole: the host builds a snapshot of the sessions alone, and `rsync` copies that.
struct OpenCodeRemoteSessionMirror {
    var runner = RemoteHostCommandRunner()
    var rsyncRemoteShell = RemoteSessionMirror.rsyncRemoteShell(connectionSharingOptions: [])

    func synchronize(host: String, destination: URL) throws {
        guard let result = runner.run(host, OpenCodeRemoteSnapshotCommand.create(on: host), 600) else {
            throw RemoteSessionMirrorError.couldNotRun(host: host)
        }
        if result.exitStatus == OpenCodeRemoteSnapshotCommand.noDatabaseExitStatus {
            try? FileManager.default.removeItem(at: destination)
            return
        }
        if result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus {
            throw RemoteSessionMirrorError.sshFailed(host: host, problem: SSHConnectionProblem(sshOutput: result.output))
        }
        guard result.exitStatus == 0, let snapshotPath = OpenCodeRemoteSnapshotCommand.snapshotPath(in: result.output) else {
            throw RemoteSessionMirrorError.rsyncFailed(
                host: host, output: "Could not snapshot OpenCode sessions. The SSH host needs python3 and a readable OpenCode database."
            )
        }
        defer { _ = runner.run(host, "rm -rf -- " + ShellQuoting.quoted(snapshotPath), 30) }
        guard
            let result = RemoteSessionMirror.runRsync(
                arguments: RemoteSessionMirror.rsyncArguments(
                    for: .opencode,
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
