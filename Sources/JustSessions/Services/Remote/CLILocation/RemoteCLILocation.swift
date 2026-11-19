import Foundation

enum RemoteCLILocation: Equatable, Sendable {
    case loginShell
    /// The login shell doesn't find the name, but the CLI is where its installer puts it, in a folder that shell's
    /// PATH leaves out, such as `~/.claude/local` or an nvm version's `bin`; see `RemoteCLIInstallFolders`. A tab
    /// starts it by this path, with its folder first on PATH, so a Node CLI finds the `node` beside it.
    case installed(path: String)
}
