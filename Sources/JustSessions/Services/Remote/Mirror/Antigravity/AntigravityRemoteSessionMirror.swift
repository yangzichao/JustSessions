import Foundation

struct AntigravityRemoteSessionMirror {
    var runner = RemoteHostCommandRunner()

    func synchronize(host: String, sourceHomeOverride: String?, destination: URL) throws {
        let snapshotPath: String
        if let sourceHomeOverride {
            let snapshot = FileManager.default.temporaryDirectory.appendingPathComponent("justsessions-agy-" + UUID().uuidString)
            do {
                try AntigravitySQLiteSnapshot.copySessionStore(
                    at: URL(fileURLWithPath: sourceHomeOverride).appendingPathComponent(RemoteSessionMirror.remoteFolder(for: .antigravity)), to: snapshot
                )
            } catch {
                try? FileManager.default.removeItem(at: snapshot)
                throw error
            }
            snapshotPath = snapshot.path
        } else {
            guard let result = runner.run(host, AntigravityRemoteSnapshotCommand.create(on: host), 600) else {
                throw RemoteSessionMirrorError.couldNotRun(host: host)
            }
            if result.exitStatus == 3 {
                try? FileManager.default.removeItem(at: destination)
                return
            }
            if result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus { throw RemoteSessionMirrorError.sshFailed(host: host) }
            guard result.exitStatus == 0, let path = AntigravityRemoteSnapshotCommand.snapshotPath(in: result.output) else {
                throw RemoteSessionMirrorError.rsyncFailed(host: host, output: "Could not snapshot Antigravity sessions. The SSH host needs python3 and readable session databases.")
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
            arguments: RemoteSessionMirror.rsyncArguments(for: .antigravity, source: source, destination: destination.path + "/"),
            includesStandardError: true, timeout: 600
        ) else { throw RemoteSessionMirrorError.couldNotRun(host: host) }
        guard result.exitStatus == 0 else {
            if result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus { throw RemoteSessionMirrorError.sshFailed(host: host) }
            throw RemoteSessionMirrorError.rsyncFailed(host: host, output: String(result.output.suffix(500)))
        }
    }
}
