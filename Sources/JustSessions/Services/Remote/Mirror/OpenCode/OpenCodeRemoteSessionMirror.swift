import Foundation

/// Copies an SSH host's OpenCode sessions. Its database also holds OpenCode's accounts and credentials, so it is
/// never copied whole: the host builds a snapshot of the sessions alone, and `rsync` copies that.
struct OpenCodeRemoteSessionMirror {
    var runner = RemoteHostCommandRunner()

    func synchronize(host: String, sourceHomeOverride: String?, destination: URL) throws {
        let snapshotPath: String
        if let sourceHomeOverride {
            let source = URL(fileURLWithPath: sourceHomeOverride)
                .appendingPathComponent(RemoteSessionMirror.remoteFolder(for: .opencode))
                .appendingPathComponent("opencode.db")
            guard FileManager.default.fileExists(atPath: source.path) else {
                try? FileManager.default.removeItem(at: destination)
                return
            }
            let snapshot = FileManager.default.temporaryDirectory.appendingPathComponent("justsessions-opencode-" + UUID().uuidString)
            do {
                try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
                try OpenCodeSQLiteSnapshot.copy(source, to: snapshot.appendingPathComponent("opencode.db"))
            } catch {
                try? FileManager.default.removeItem(at: snapshot)
                throw error
            }
            snapshotPath = snapshot.path
        } else {
            guard let result = runner.run(host, OpenCodeRemoteSnapshotCommand.create(on: host), 600) else {
                throw RemoteSessionMirrorError.couldNotRun(host: host)
            }
            if result.exitStatus == OpenCodeRemoteSnapshotCommand.noDatabaseExitStatus {
                // OpenCode was never used on this host.
                try? FileManager.default.removeItem(at: destination)
                return
            }
            if result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus {
                throw RemoteSessionMirrorError.sshFailed(host: host, problem: SSHConnectionProblem(sshOutput: result.output))
            }
            guard result.exitStatus == 0, let path = OpenCodeRemoteSnapshotCommand.snapshotPath(in: result.output) else {
                throw RemoteSessionMirrorError.rsyncFailed(host: host, output: "Could not snapshot OpenCode sessions. The SSH host needs python3 and a readable OpenCode database.")
            }
            snapshotPath = path
        }
        defer {
            if sourceHomeOverride != nil { try? FileManager.default.removeItem(atPath: snapshotPath) }
            else { _ = runner.run(host, "rm -rf -- " + ShellQuoting.quoted(snapshotPath), 30) }
        }
        let source = sourceHomeOverride != nil ? snapshotPath + "/" : host + ":" + snapshotPath + "/"
        guard let result = BoundedProcessRunner.result(
            ofExecutable: "/usr/bin/rsync",
            arguments: RemoteSessionMirror.rsyncArguments(for: .opencode, source: source, destination: destination.path + "/"),
            includesStandardError: true, timeout: 600
        ) else { throw RemoteSessionMirrorError.couldNotRun(host: host) }
        guard result.exitStatus == 0 else {
            if result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus {
                throw RemoteSessionMirrorError.sshFailed(host: host, problem: SSHConnectionProblem(sshOutput: result.output))
            }
            throw RemoteSessionMirrorError.rsyncFailed(host: host, output: String(result.output.suffix(500)))
        }
    }
}
