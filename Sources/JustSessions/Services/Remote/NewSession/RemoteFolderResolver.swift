import Foundation

enum RemoteFolderResolutionError: LocalizedError, Equatable {
    case couldNotRun(host: String)
    case sshFailed(host: String)
    case missingFolder(host: String, folder: String)

    var errorDescription: String? {
        switch self {
        case .couldNotRun(let host):
            "Looking up the folder on \(host) did not finish within 30 seconds."
        case .sshFailed(let host):
            "Could not connect to \(host). Check that `ssh \(host)` works in Terminal without a password prompt."
        case .missingFolder(let host, let folder):
            "There is no folder \(folder) on \(host)."
        }
    }
}

/// Looks up a folder typed for a new session on an SSH host and returns its absolute path with symlinks resolved,
/// which is the path the CLI records for the session. `~` is the home folder on the host, and so is the base of a
/// relative path.
struct RemoteFolderResolver: Sendable {
    let runner: RemoteHostCommandRunner

    init(runner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        self.runner = runner
    }

    func resolvedPath(of typedFolder: String, host: String) throws -> String {
        guard let result = runner.run(host, Self.lookupCommand(for: typedFolder), 30) else {
            throw RemoteFolderResolutionError.couldNotRun(host: host)
        }
        if result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus {
            throw RemoteFolderResolutionError.sshFailed(host: host)
        }
        guard result.exitStatus == 0, let path = Self.absolutePath(inOutput: result.output) else {
            throw RemoteFolderResolutionError.missingFolder(host: host, folder: typedFolder)
        }
        return path
    }

    /// A POSIX `sh` script, so it runs the same whatever the host's login shell is. `ssh` starts in the home folder.
    static func lookupCommand(for typedFolder: String) -> String {
        let script = #"cd -- "$1" && pwd -P"#
        return "sh -c \(ShellQuoting.quoted(script)) sh \(ShellQuoting.quoted(homeRelativeFolder(typedFolder)))"
    }

    /// `~` and `~/…` become relative to the home folder, where the lookup starts.
    static func homeRelativeFolder(_ typedFolder: String) -> String {
        guard typedFolder == "~" || typedFolder.hasPrefix("~/") else { return typedFolder }
        let pathInHome = typedFolder.dropFirst(2)
        return pathInHome.isEmpty ? "." : String(pathInHome)
    }

    /// The last absolute path printed; a shell profile may print lines of its own first.
    static func absolutePath(inOutput output: String) -> String? {
        output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { $0.hasPrefix("/") }
    }
}
