import Foundation

/// Looks up a folder typed for a new session on an SSH host and returns its absolute path with symlinks resolved,
/// which is the path the CLI records for the session. `~` is the home folder on the host, and so is the base of a
/// relative path. Adding a project can create the folder first, with any missing parents, once asked to.
struct RemoteFolderResolver: Sendable {
    let runner: RemoteHostCommandRunner

    init(runner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        self.runner = runner
    }

    func resolvedPath(of typedFolder: String, host: String, creatingMissingFolder: Bool = false) throws -> String {
        let command = Self.lookupCommand(for: typedFolder, creatingMissingFolder: creatingMissingFolder)
        guard let result = runner.run(host, command, 30) else {
            throw RemoteFolderResolutionError.couldNotRun(host: host)
        }
        if result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus {
            throw RemoteFolderResolutionError.sshFailed(host: host)
        }
        guard result.exitStatus == 0, let path = Self.absolutePath(inOutput: result.output) else {
            throw creatingMissingFolder
                ? RemoteFolderResolutionError.couldNotCreateFolder(host: host, folder: typedFolder)
                : RemoteFolderResolutionError.missingFolder(host: host, folder: typedFolder)
        }
        return path
    }

    /// A POSIX `sh` script, so it runs the same whatever the host's login shell is. `ssh` starts in the home folder.
    static func lookupCommand(for typedFolder: String, creatingMissingFolder: Bool = false) -> String {
        let script = creatingMissingFolder ? #"mkdir -p -- "$1" && cd -- "$1" && pwd -P"# : #"cd -- "$1" && pwd -P"#
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
